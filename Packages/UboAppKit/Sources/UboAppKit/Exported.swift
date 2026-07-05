// App targets only need `import UboAppKit`; the widget-safe shared layer
// is re-exported here. The widget extension imports UboAppShared directly
// so it never links the gRPC stack.
@_exported import UboAppShared
