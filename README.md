# Godot iOS Deploy

godot ios export test

> Deploy to iOS for testing in one click from within Godot!

## NOTE

This addon is rough around the edges. Looking forward to getting feedback and
hearing about ways to improve workflow, usability, and QoL.

## Features

1. Supports Godot versions 2 and 3 in one package
2. One click deploy
3. No need to open xcode (after you have registered your apple developer account and downloaded manual provisioning profiles)
4. Finds installed provisioning profiles and teams
5. Automatic xcode managed provisions (automanaged)
6. Builds and signs project
7. Deploy to multiple ios devices in parallel
8. Onboarding flow for easy project setup
9. Set custom godot binary
10. Deploy with debug collisions and debug navigation

## Prerequisites

1. macOS
2. Xcode and its command line tools
    - Install Xcode from the App Store and
    - Open Terminal and type `xcode-select --install`
3. iOS Developer account
    - sign up on [developer.apple.com](https://developer.apple.com), its free
    - Open Xcode and register your account
4. [Godot export templates](https://godotengine.org/download)
6. [ios-deploy](https://github.com/ios-control/ios-deploy) OR see below
    - Install with [homebrew](https://brew.sh): `brew install ios-deploy`
7. [libimobiledevice](https://www.libimobiledevice.org) OR see above
    - Install with [homebrew](https://brew.sh): `brew install libimobiledevice`
8. To automatically launch your installed game by ensuring debugger support for
   your device
    1. Open Xcode and go to *Window > Devices and Simulators* while device is
       connected.
    2. Select you device and at the top it should say "Preparing Debugger
       Support"
    3. Wait awhile. That's it.

## Install

1. Download or clone this repo
2. Put com.indicainkwell.iosdeploy folder into the addons folder of your godot
   project

I will eventually put this up on the asset library.

## Usage

An apple button will appear in Godot Editor's toolbar. Pressing this button
will

1. Open onboarding flow menu if not setup or
2. Begin build and deploy

Hovering over the button will show a popup with

1. The progress of the build and deploy.
2. A settings button to open up the settings menu.
3. A checkmark the tells you if the project is valid and setup.
4. **Device selection**, use this to choose what devices to deploy to.

The settings menu allows you to

* Open onboarding flow
* Open or copy path to generated xcode project
* Choose deploy tool: ios-deploy or libimobiledevice
* Set custom path to deploy tool
* Set custom godot binary
* Fill in ios export presets
	- requires restarting godot
* Set Logger file and level

### Godot Debug Features

Enable debug collisions, and debug navigation through Godot > Debug.

See [here](https://docs.godotengine.org/en/3.1/tutorials/debug/overview_of_debugging_tools.html).

## Troubleshooting

If all goes well it will attempt to deploy it, but can fail for multiple reasons:

1. Security Failure
    - You must verify your app or developer account on your iOS device by going
      to `Settings > General > Device Management > Your account` and tap verify.
2. More in todos.todo
3. ...

Check Godot's output panel for errors and messages.

Control logging by exporting any of the following environment variables:

    export COM_INDICAINKWELL_IOSDEPLOY_LOGGER_FILE=/path/to/my/logfile.txt
    export COM_INDICAINKWELL_IOSDEPLOY_LOGGER_LEVEL=verbose

Logger file can use `res://` and `user://` or be an absolute or relative path
from the project.

Logger levels are `verbose`, `debug`, `info`, `warn`, and `error`.

You can also set it in the settings menu.
