enum DocumentActionRequest: Equatable {
    case copy
    case move
    case rename
    case export(DocumentExportFormat)
    case print
}
