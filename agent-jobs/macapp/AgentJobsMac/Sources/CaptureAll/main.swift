// `capture-all` CLI — produces the 10-scenario PNG/JSON set the
// ui-critic agent reviews. Real implementation lands in T08; this
// placeholder lets the SPM target build under T01.

import Foundation

let args = CommandLine.arguments
FileHandle.standardError.write(Data("capture-all: not yet implemented (M05 T08 pending)\n".utf8))
_ = args
exit(0)
