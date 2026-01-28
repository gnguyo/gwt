# gwt

A Git Worktree Manager using [gum](https://github.com/charmbracelet/gum) for beautiful interactive CLI prompts.

Inspired by [gko/gwt](https://github.com/gko/gwt) but built with [charmbracelet/gum](https://github.com/charmbracelet/gum) instead of fzf.

## Features

- **Interactive Navigation** — Select worktrees from a filterable menu
- **Quick Add** — Create new worktrees with interactive branch selection
- **Easy Removal** — Remove worktrees interactively with confirmation
- **Direct Access** — Jump to specific branch worktrees by name
- **Main Branch Shortcut** — Navigate directly to main/master worktree

## Installation

### Dependencies

- [gum](https://github.com/charmbracelet/gum) — Install with `brew install gum` or see [gum installation docs](https://github.com/charmbracelet/gum#installation)
- git with worktree support

### Setup

Clone the repository and source the script in your shell configuration:

```bash
# Clone
git clone https://github.com/yourusername/gwt.git ~/.gwt

# Add to ~/.bashrc or ~/.zshrc
source ~/.gwt/gwt.sh
```

Or download just the script:

```bash
curl -o ~/.gwt.sh https://raw.githubusercontent.com/yourusername/gwt/main/gwt.sh
echo 'source ~/.gwt.sh' >> ~/.bashrc
```

## Usage

```
gwt                     # Interactive worktree selection
gwt add [branch]        # Create and switch to new worktree
gwt main                # Jump to main branch worktree
gwt master              # Jump to master branch worktree
gwt <branch>            # Jump to specific branch worktree
gwt remove [-f|--force] # Remove worktrees interactively
gwt --help              # Display help
```

### Examples

```bash
# Pick from existing worktrees
gwt

# Create worktree with interactive branch picker
gwt add

# Create worktree for a specific branch
gwt add feature/login

# Filter branches starting with "feat"
gwt add feat

# Jump to main branch worktree
gwt main

# Remove a worktree interactively
gwt remove

# Force remove a worktree
gwt remove -f
```

## How It Works

- Worktrees are created alongside the main repository with a hash suffix
  - e.g., `/var/www/my-project` → `/var/www/my-project-bace48f`
- The hash is derived from the branch name for consistency
- If a path already exists, a new unique hash is generated
- Main/master branches cannot be added as worktrees (use `gwt main` to navigate)

## License

GPL-3.0

## Credits

- Inspired by [gko/gwt](https://github.com/gko/gwt)
- Built with [charmbracelet/gum](https://github.com/charmbracelet/gum)
