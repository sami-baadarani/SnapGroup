//
//  DebugLog.swift
//  SnapGroup
//

#if DEBUG
func debugLog(_ items: Any..., separator: String = " ") {
    print(items.map { "\($0)" }.joined(separator: separator))
}
#else
@inline(__always) func debugLog(_ items: Any..., separator: String = " ") {}
#endif
