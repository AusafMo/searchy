# Searchy
>Photo managment on mac sucks, so this is my attempt at making
<br>

   A (somewhat) better, lightweight way to ***browse*, *search*, and *potentially manage*** images on mac. A work in progress.
<br>

  Entirely **on-device**, except model fetching. More models, UI improvements and other customizations in pipe.

## Demo
https://github.com/user-attachments/assets/ec7f203c-3e59-49d9-9aa8-a0b171eaaae7

## To-DO

### New Feat (not in order)
  ---
  - [ ] Duplicate deleter, i.e., more image managing.
  - [ ] Custom Models, right now, using CLIP, potentially using smaller and lighter models or even domain specific tuned models, like fashion, art etc
  - [ ] Custom user scripts for indexing, querying, adhereing to (yet to decide) schema. Essentially making the front end plug and play.
  - [ ] Offloading model if the user sets a  `time to offload `
  - [ ] More filters: time etc
  - [ ] Hybrid search over captions (either user provided via api_keys (replicate/hf etc) for off the shelf models or otherwise manual short captions entered by user)
  - [ ] making a spotlight style widget
  - [ ] Crude Tags/Class implementaion based on user provided classes/tags.

### Improvements (not in order, I am NOT a swift guy, I can try my best)
  ---
  - [ ] Making UI more clean and less crappy really.
  - [ ] fixing hotkey issue, currently the hot key to bring the app to attention `⌘ + ⇧ + Space`, which is buggy.
  - [ ] Figure out how to bundling the app to be distributed, need real help on this one.
  - [ ] Fixing the indexing stats after indexing finishes, it disappears too quickly, make it a pop if possible.
