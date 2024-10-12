# Create Lightfield Quilt with Godot

This program creates a quilt from a lightfield photo set.
It is made for my own use, so it may have many bugs.

The original logic is looking-gloves (https://github.com/m0o0scar/looking-gloves).

## Usage

Lightfield photoset should have sortable filename (00001.jpg, 00002.jpg, 00003.jpg...).

Click the "Select Images" button and select images,
or drag and drop a folder containing light field images.

If you need to crop the image, select the mode from the combo box and crop the image by dragging the mouse.

Adjust focus by slider. If you need to reverse the order of the images, click the "Flip" button.

Finally, you can click the "Create Quilt" button.
This button shows a quilt image on the right side.
You can save it by clicking "Save Quilt" button. 

## Notice

The initial image is for testing the slider and cannot be saved as a quilt image.

Due to the limitations of the Godot image class,
too many photos and/or photos that are too large may result in failure to create a quilt.

## License

MIT.

See LICENSE.md.
