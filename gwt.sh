#!/usr/bin/env bash
#
# gwt - Git Worktree Manager
# A CLI tool for managing Git worktrees using gum for interactive UI
#

# Print help/usage information
_gwt_print_help() {
    cat << 'EOF'
gwt - Git Worktree Manager

Usage:
    gwt                     Interactive worktree selection
    gwt add [branch]        Create and switch to new worktree
                            (interactive branch picker if omitted)
    gwt main                Jump to main branch worktree
    gwt master              Jump to master branch worktree
    gwt <branch>            Jump to specific branch worktree
    gwt remove [-f|--force] Remove worktrees interactively
    gwt --help              Display this help message

Dependencies:
    - gum (https://github.com/charmbracelet/gum)
    - git with worktree support

Examples:
    gwt                     # Pick from existing worktrees
    gwt add                 # Pick branch interactively, create worktree
    gwt add feature/login   # Create worktree for feature/login branch
    gwt add feat            # Filter branches starting with "feat"
    gwt main                # Jump to main branch worktree
    gwt remove              # Interactively remove a worktree
    gwt remove -f           # Force remove a worktree
EOF
}

# Check if required dependencies are available
_gwt_check_deps() {
    if ! command -v gum &> /dev/null; then
        echo "Error: gum is not installed. Install it with: brew install gum" >&2
        return 1
    fi
    if ! command -v git &> /dev/null; then
        echo "Error: git is not installed." >&2
        return 1
    fi
    if ! git rev-parse --git-dir &> /dev/null 2>&1; then
        echo "Error: Not in a git repository." >&2
        return 1
    fi
    return 0
}

# Get the main worktree path
_gwt_get_main_worktree() {
    git worktree list --porcelain | head -1 | sed 's/worktree //'
}

# Generate a unique short hash for worktree path
# Usage: _gwt_hash <base_path> <branch>
_gwt_hash() {
    local base_path="$1"
    local branch="$2"
    local counter=0
    local hash
    local full_path

    while true; do
        if [[ $counter -eq 0 ]]; then
            hash=$(echo -n "$branch" | sha1sum | cut -c1-7)
        else
            hash=$(echo -n "${branch}${counter}" | sha1sum | cut -c1-7)
        fi
        full_path="${base_path}-${hash}"

        if [[ ! -e "$full_path" ]]; then
            echo "$hash"
            return 0
        fi

        ((counter++))
    done
}

# Detect the default branch (main or master)
_gwt_detect_default_branch() {
    local default_branch

    # Try to get from remote HEAD
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    # Fallback: check if main exists
    if [[ -z "$default_branch" ]]; then
        if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
            default_branch="main"
        elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
            default_branch="master"
        fi
    fi

    echo "$default_branch"
}

# Jump to the default branch worktree (main or master)
_gwt_jump_to_default() {
    local target_branch="$1"
    local default_branch

    if [[ -n "$target_branch" ]]; then
        default_branch="$target_branch"
    else
        default_branch=$(_gwt_detect_default_branch)
    fi

    if [[ -z "$default_branch" ]]; then
        echo "Error: Could not detect default branch (main/master)." >&2
        return 1
    fi

    # Find the worktree for this branch
    local worktree_path
    worktree_path=$(git worktree list --porcelain | grep -A2 "^worktree " | \
        awk -v branch="$default_branch" '
            /^worktree / { path = substr($0, 10) }
            /^branch / {
                b = substr($0, 8)
                gsub(/refs\/heads\//, "", b)
                if (b == branch) print path
            }
        ' | head -1)

    if [[ -z "$worktree_path" ]]; then
        echo "Error: No worktree found for branch '$default_branch'." >&2
        return 1
    fi

    cd "$worktree_path" || return 1
    echo "Switched to: $worktree_path"
}

# Check if a git branch exists
_gwt_is_git_branch() {
    local branch_name="$1"
    if [[ $(git branch --list "$branch_name") ]]; then
        return 0
    else
        return 1
    fi
}

# Interactive branch selection (like git_branch)
_gwt_branch() {
    local BRANCH

    if [[ -z "$1" ]]; then
        BRANCH=$(git branch --format='%(refname:short)' | gum filter --placeholder="Select branch...")
    else
        if _gwt_is_git_branch "$1"; then
            BRANCH="$1"
        else
            BRANCH=$(git branch --format='%(refname:short)' | gum filter --placeholder="Select branch..." --value="$1")
        fi
    fi

    echo "$BRANCH"
}

# Create a new worktree for a branch
_gwt_add() {
    local branch
    branch=$(_gwt_branch "$1")

    if [[ -z "$branch" ]]; then
        echo "No branch selected."
        return 1
    fi

    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        echo "Error: Cannot create worktree for $branch. Use 'gwt $branch' to jump to it." >&2
        return 1
    fi

    local main_worktree
    main_worktree=$(_gwt_get_main_worktree)
    local branch_hash
    branch_hash=$(_gwt_hash "$main_worktree" "$branch")
    local worktree_path="${main_worktree}-${branch_hash}"

    # Check if branch exists locally
    local branch_exists_local=false
    local branch_exists_remote=false

    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        branch_exists_local=true
    fi

    # Check if branch exists on remote
    if git ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
        branch_exists_remote=true
    fi

    if [[ "$branch_exists_local" == "true" ]]; then
        # Branch exists locally, create worktree
        git worktree add "$worktree_path" "$branch"
    elif [[ "$branch_exists_remote" == "true" ]]; then
        # Branch exists on remote, create worktree tracking remote
        git worktree add "$worktree_path" "$branch"
    else
        # Branch doesn't exist, prompt to create
        if gum confirm "Branch '$branch' doesn't exist. Create it?"; then
            git worktree add -b "$branch" "$worktree_path"
        else
            echo "Aborted."
            return 1
        fi
    fi

    if [[ $? -eq 0 ]]; then
        cd "$worktree_path" || return 1
        echo "Switched to: $worktree_path"
    else
        echo "Error: Failed to create worktree." >&2
        return 1
    fi
}

# Remove a worktree interactively
_gwt_remove() {
    local force_flag=""

    # Check for force flag
    if [[ "$1" == "-f" || "$1" == "--force" ]]; then
        force_flag="--force"
    fi

    # Get list of worktrees (excluding the main one)
    local worktrees
    worktrees=$(git worktree list | tail -n +2)

    if [[ -z "$worktrees" ]]; then
        echo "No additional worktrees to remove."
        return 0
    fi

    # Let user select a worktree
    local selected
    selected=$(echo "$worktrees" | gum filter --placeholder "Select worktree to remove...")

    if [[ -z "$selected" ]]; then
        echo "No worktree selected."
        return 0
    fi

    # Extract the path from the selection
    local worktree_path
    worktree_path=$(echo "$selected" | awk '{print $1}')

    # Confirm removal
    if gum confirm "Remove worktree at '$worktree_path'?"; then
        # If we're in the worktree being removed, cd to main first
        if [[ "$(pwd)" == "$worktree_path"* ]]; then
            local main_worktree
            main_worktree=$(_gwt_get_main_worktree)
            cd "$main_worktree" || return 1
        fi

        git worktree remove $force_flag "$worktree_path"
        if [[ $? -eq 0 ]]; then
            echo "Removed worktree: $worktree_path"
        else
            echo "Error: Failed to remove worktree. Try with -f/--force flag." >&2
            return 1
        fi
    else
        echo "Aborted."
    fi
}

# Jump to a specific branch worktree
_gwt_jump_to_branch() {
    local branch="$1"

    # Find the worktree for this branch
    local worktree_path
    worktree_path=$(git worktree list --porcelain | grep -A2 "^worktree " | \
        awk -v branch="$branch" '
            /^worktree / { path = substr($0, 10) }
            /^branch / {
                b = substr($0, 8)
                gsub(/refs\/heads\//, "", b)
                if (b == branch) print path
            }
        ' | head -1)

    if [[ -z "$worktree_path" ]]; then
        echo "Error: No worktree found for branch '$branch'." >&2
        echo "Use 'gwt add $branch' to create one." >&2
        return 1
    fi

    cd "$worktree_path" || return 1
    echo "Switched to: $worktree_path"
}

# Interactive worktree selection
_gwt_interactive() {
    local worktrees
    worktrees=$(git worktree list)

    if [[ -z "$worktrees" ]]; then
        echo "No worktrees found."
        return 1
    fi

    # Let user select a worktree
    local selected
    selected=$(echo "$worktrees" | gum filter --placeholder "Select worktree...")

    if [[ -z "$selected" ]]; then
        echo "No worktree selected."
        return 0
    fi

    # Extract the path from the selection
    local worktree_path
    worktree_path=$(echo "$selected" | awk '{print $1}')

    cd "$worktree_path" || return 1
    echo "Switched to: $worktree_path"
}

# Main gwt function
gwt() {
    # Check dependencies first
    _gwt_check_deps || return 1

    # Parse arguments
    case "${1:-}" in
        --help|-h)
            _gwt_print_help
            ;;
        add)
            _gwt_add "$2"
            ;;
        remove|rm)
            _gwt_remove "$2"
            ;;
        main)
            _gwt_jump_to_default "main"
            ;;
        master)
            _gwt_jump_to_default "master"
            ;;
        "")
            _gwt_interactive
            ;;
        *)
            # Try to jump to the specified branch
            _gwt_jump_to_branch "$1"
            ;;
    esac
}
