# Palmface's dependencies. Install with:  brew bundle --file=Brewfile
# (install.sh never runs brew; it prints this line.) Everything in the kit checks that a tool
# exists before using it, so you can trim this list.

# ── Terminal ──
# Ghostty downloaded by hand? Then the cask would fail on the existing app; skip it.
ghostty_app = ["/Applications", File.expand_path("~/Applications")].any? { |d| File.exist?("#{d}/Ghostty.app") }
ghostty_brew = Dir.exist?("#{ENV.fetch("HOMEBREW_PREFIX", "/opt/homebrew")}/Caskroom/ghostty")
cask "ghostty" unless ghostty_app && !ghostty_brew
cask "font-maple-mono"
brew "starship"
brew "tmux"
brew "tmuxinator"

# ── Everyday tools (aliases and integrations in vibes.zsh) ──
brew "eza"
brew "bat"
brew "fzf"
brew "zoxide"
brew "git-delta"
brew "jq"            # macOS 15+ ships /usr/bin/jq; install.sh needs jq only for json layers

# ── Claude Code ──
brew "node"          # runs the statusline (~/.claude/palmface/statusline). Already use nvm,
                     # volta or asdf? Drop this line: any node 18+ on your PATH works.

# ── Delight ──
brew "figlet"
brew "cowsay"
brew "lolcat"

# ── Optional: uncomment for more toys and typing feedback ──
# brew "cbonsai"                   # zen, bonsai, and the screensaver
# brew "pipes-sh"                  # pipes, and the screensaver
# brew "cmatrix"                   # matrix, and the screensaver
# brew "asciiquarium"              # aquarium
# brew "nyancat"                   # nyan
# brew "fortune"                   # owl/meow speak fortunes; the statusline whispers one
# brew "glow"                      # md: render markdown in the terminal
# brew "chafa"                     # show: images as real pixels in Ghostty
# brew "zsh-autosuggestions"       # grey suggestions from your history as you type
# brew "zsh-syntax-highlighting"   # colours commands as you type
