#!/bin/bash

echo "Setting up Emacs dotfiles configuration..."

DOTFILES_DIR="$HOME/dotfiles"

# Simple symlink creation
echo "Creating symlinks..."
ln -sf "$DOTFILES_DIR/.spacemacs" "$HOME/.spacemacs"
ln -sf "$DOTFILES_DIR/config" "$HOME/.emacs.d/config"
ln -sf "$DOTFILES_DIR/snippets" "$HOME/.emacs.d/snippets"

echo "✅ Emacs configuration setup complete!"
echo "Restart Emacs to load the new configuration."
