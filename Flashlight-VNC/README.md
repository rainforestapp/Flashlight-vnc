# Build Instructions (Linux) for CI/CD purposes

Based on those found [here](https://cwiki.apache.org/confluence/display/FLEX/1.2+Setting+up+Manually)

You can download the Flex SDK binaries from [here](http://flex.apache.org/download-binaries.html) and the AIR SDK from [here](http://www.adobe.com/devnet/air/air-sdk-download.html), you should get the Windows archive.

Other dependencies are ant and java (I tested with ant 1.9.6 and Java 1.7.0_85 IcedTea).

```bash
mkdir flash
cd flash
export FLEX_BASE=$PWD

wget http://www.apache.org/dyn/closer.lua/flex/4.14.1/binaries/apache-flex-sdk-4.14.1-bin.tar.gz
tar zxf apache-flex-sdk-4.14.1-bin.tar.gz
(cd apache-flex-sdk-4.14.1-bin/frameworks; ant thirdparty-downloads -Dfont.donot.ask=true)

wget http://airdownload.adobe.com/air/win/download/latest/AdobeAIRSDK.zip
mkdir AIRSDK
unzip AdobeAIRSDK.zip -d AIRSDK
export AIR_HOME=$FLEX_BASE/AIRSDK

export PLAYERGLOBAL_HOME=$FLEX_BASE/player
mkdir -p $PLAYERGLOBAL_HOME/11.1
wget -nc https://fpdownload.macromedia.com/get/flashplayer/updaters/18/playerglobal18_0.swc -P $PLAYERGLOBAL_HOME/11.1
(cd $PLAYERGLOBAL_HOME/11.1/; ln -s playerglobal{18_0,}.swc)

export PATH=$FLEX_BASE/apache-flex-sdk-4.14.1-bin/bin:$PATH
```

You can then compile with (n.b. `AIR_HOME` and `PLAYERGLOBAL_HOME` must be set):
```bash
(
  cd ~/code/Flashlight-vnc/Flashlight-VNC;
  mxmlc -locale=en_US -warnings -verify-digests -target-player=11.1.0 -compiler.strict -compiler.accessible=false -remove-unused-rsls -output bin/Flashlight.swf -compiler.defaults-css-files+=MXFTEText.css -outfile bin/Flashlight.swf ./src/Flashlight.mxml
)
```

Or:
```bash
ant main
```

# HTML

You can generate the HTML required to display the plugin with the command:
```bash
ant main && ant wrapper
```

You will have to modify the index.html to set flashvars to something like:
```javascript
var flashvars = {
    autoConnect: true,
    autoReConnect: true,
    encoding: "hextile",
    hideControls: true,
    hideSettings: true,
    jpegCompression: 8,
    scale: true,
    useRemoteCursor: false,
    viewOnly: false,
    host: "vnc.host.example.com",
    port: 5901,
    password: "cbe8f59d2c5241e101d7283ac04da1c2",
};
params.allowscriptaccess = "always";
```

# Debugging

Forget about it under Linux, I completely failed to install the plugins into Chrome or Firefox. Also, the debug plugin is only 32bit. If you want to try, you can get them from the following links:
* http://www.adobe.com/support/flashplayer/debug_downloads.html
* https://fpdownload.macromedia.com/pub/flashplayer/updaters/11/flashplayer_11_sa.i386.tar.gz
* https://fpdownload.macromedia.com/pub/flashplayer/updaters/11/flashplayer_11_plugin_debug.i386.tar.gz
* https://fpdownload.macromedia.com/pub/flashplayer/updaters/11/flashplayer_11_sa_debug.i386.tar.gz
