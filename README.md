# 👉  Narrow

Neovim search editor inspired by the fantastic [atom-narrow](https://github.com/t9md/atom-narrow)

####  About
Narrow is an editor oriented search plugin that places grep search results in a fully modifiable editor with automatic file/line preview. Result lines can be modified and updates to real file can be applied - making changes across multiple files a breeze. 

#### Current State
It's stable enough that I'm daily driving it at my 9-5, but it's still in the early prototyping phase!
- [x] basic ripgrep project searching
- [x] update real files (naive implementation)
- [ ] preview file (~disabled~ commented out 😅)

#### Why
Placing search results in a modifiable buffer allows us to use all of vim's built-in goodies for working with our results. My search habbits often constisting of ripgrep over an initial pattern, and then searching within the results buffer to "narrow" things down. Search and replace in the buffer allows for low effort global search and replace too


<img width="1946" alt="Screen Shot 2022-10-21 at 11 25 11 PM" src="https://user-images.githubusercontent.com/1953178/197323921-32609aec-d44f-4a49-b5ac-4485a573de40.png">
