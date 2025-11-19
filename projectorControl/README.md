# Projector Control
## For Digital Projection HIGHLite Laser 3D II. 
This is a highly case-specific plugin I developped to provide a reusable and easy to set up interface to control our video projectors from the MA desk, in order to avoid having to hike up into the control room to use the remote to adjust settings.

It will probably work with other projectors of the same brand as they share a lot of the control protocol, but double check the manuals to see if a given command is available with your specific model. 
### What it does
The plugin will set up a new OSC interface that will send commands to a host Raspberry Pi running the amazing [Chataigne](https://benjamin.kuperberg.fr/chataigne/en) software. Chataigne essentially acts as an OSC to Serial translation layer. It can do a lot more, I encourage you to check it out.
### Usage
Import and run the plugin. A popup window will allow you to adjust the OSC setings and pick where you want the macros to be created. If you check "Auto macro index" box it will add them after the last valid macro in your Default pool.\
Make sure that your Network Interface configuration matches the IP range of the OSC destination.

### Possible future improvements
- "Preset Memory" to be able to store and recall different projector settings
- Implement more of the projector features
- Configure Network Interface from setup dialog
- Create and assign new appearance to created macros to make them pop out
- Better way to access excutor properties
