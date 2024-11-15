# 👉  Narrow

Neovim search editor inspired by the fantastic [atom-narrow](https://github.com/t9md/atom-narrow)

####  About
Narrow is an editor oriented search plugin that places grep search results in a fully modifiable editor with automatic file/line preview. Result lines can be modified and updates to real file can be applied - making changes across multiple files a breeze. 

#### Current State
It's stable enough that I'm daily driving it at my 9-5, but it's still in the early stages!
- [x] basic ripgrep project searching
- [x] update real files
- [ ] preview file

#### Why
Placing search results in a modifiable buffer allows us to use all of vim's built-in goodies for working with our results. My search habbits often constisting of ripgrep over an initial pattern, and then searching within the results buffer to "narrow" things down. Search and replace in the buffer allows for low effort global search and replace too


<img width="1296" alt="Screenshot 2024-11-15 at 7 44 40 AM" src="https://github.com/user-attachments/assets/a7b49404-c2b1-4842-9126-8b2e4e999e0e">
