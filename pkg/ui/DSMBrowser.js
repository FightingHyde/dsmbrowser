Ext.namespace("SYNO.SDS.DSMBrowser.Utils");

Ext.apply(SYNO.SDS.DSMBrowser.Utils, function () {
    return {
        getMainHtml: function () {
            // served same-origin from /webman/3rdparty/DSMBrowser/ -> no framing/cert issues
            return '<iframe src="webman/3rdparty/DSMBrowser/novnc/vnc.html'
                 + '?autoconnect=1&reconnect=1&resize=scale'
                 + '&host=' + window.location.hostname
                 + '&port=6081&path=websockify'
                 + '&_ts=' + new Date().getTime() + '" title="chromium" '
                 + 'style="width:100%;height:100%;border:none;margin:0"/>';
    };
}());

Ext.define("SYNO.SDS.DSMBrowser.Application", {
    extend: "SYNO.SDS.AppInstance",
    appWindowName: "SYNO.SDS.DSMBrowser.MainWindow",
    constructor: function () { this.callParent(arguments); }
});

Ext.define("SYNO.SDS.DSMBrowser.MainWindow", {
    extend: "SYNO.SDS.AppWindow",
    constructor: function (a) {
        var MY = SYNO.SDS.DSMBrowser;
        this.appInstance = a.appInstance;
        MY.MainWindow.superclass.constructor.call(this, Ext.apply({
            layout: "fit",
            resizable: true,
            maximizable: true,
            minimizable: true,
            width: 1280,
            height: 800,
            html: MY.Utils.getMainHtml()
        }, a));
        MY.Utils.ApplicationWindow = this;
    },
    onClose: function () {
        SYNO.SDS.DSMBrowser.MainWindow.superclass.onClose.apply(this, arguments);
        this.doClose();
        return true;
    }
});
