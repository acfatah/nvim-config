# nvim-config

Personal [AstroNvim](https://github.com/AstroNvim/AstroNvim) v6+ config.
What is customized and why: [docs/SETUP.md](docs/SETUP.md).

## 🛠️ Installation

#### Make a backup of your current nvim and shared folder

```shell
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

#### Clone the repository

```shell
git clone https://github.com/acfatah/nvim-config ~/.config/nvim
```

#### Start Neovim

```shell
nvim
```

#### After cloning (other machines)

- Install a Nerd Font on the host terminal (see docs/SETUP.md step 0).
- codetime.dev token: `codetime token set <token>` or export
  `CODETIME_TOKEN`. It is never stored in this repo.
- Plugin versions are pinned by `lazy-lock.json`; run `:Lazy restore` to
  match them exactly.
