import PatchCore
import SwiftUI
import UniformTypeIdentifiers

/// An export wrapped so `ShareLink` can hand it to anything — Files, AirDrop,
/// Mail, another app.
///
/// `Transferable` rather than writing a temporary file: there is nothing to
/// clean up afterwards, and the data never touches the disk unless the person
/// chooses somewhere to put it.
struct ExportFile: Transferable {
    let document: ExportDocument
    let type: UTType

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            file.document.data
        }
        .suggestedFileName { $0.document.filename }
        .exportingCondition { $0.type == .json }

        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            file.document.data
        }
        .suggestedFileName { $0.document.filename }
        .exportingCondition { $0.type == .commaSeparatedText }
    }
}
