crossbow
========

Crossbow is an image browser and view for macOS 12+ similar to ACDSee on Windows. 
  
Some key features include:
* Thumbnail image browser with preview.
* Image viewer with fullscreen slideshow.
* Supports all Core Image file formats including jpeg, gif, png, tiff, pdf and raw.
* Displays image metadata including exif, iptc and gps.

Download:
https://github.com/FigBug/crossbow/releases

Screenshots:

![alt tag](http://www.socalabs.com/screen1.png)

![alt tag](http://www.socalabs.com/screen2.png)

Building
--------

Open `Crossbow.xcodeproj` (clone with `--recurse-submodules`, Malus is a submodule). There are two targets:

* **Crossbow** - direct download build. Browses every mounted volume, not sandboxed. This is what CI signs, notarizes and publishes.
* **Crossbow App Store** - sandboxed build (`APPSTORE=1`) that only browses folders the user has added.

