# Indicator Synapse

For those of you who can't live without the useful indicator-synapse, it now works with elementary os loki :-)

This codebase bundles the original [Synapse Launcher project](https://launchpad.net/synapse-project) code and retains its original license. It does not use Synapse's UI part and instead provides a Wingpanel indicator.

![Screenshot](https://raw.githubusercontent.com/tom95/indicator-synapse/master/screenshots/Screenshot.png)

### Build instructions
```
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr ../
make   
sudo make install
```
### Global Shortcut
To open the indicator via shortcut, add a custom shortcut in your keyboard settings with the following command:
```
wingpanel --toggle-indicator=com.github.tom95.indicator-synapse
```
