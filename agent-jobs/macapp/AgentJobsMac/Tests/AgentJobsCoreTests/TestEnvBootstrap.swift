import Foundation

/// Test-bundle bootstrap: sets `AGENTJOBS_TEST=1` so production code paths
/// that use `RealStopExecutor` will fatal if accidentally invoked from a
/// test (defense in depth — see T08 / AC-Q-05). Lives in a top-level
/// initializer so it runs at bundle load time, before any `@Suite` body.
///
/// `StopExecutorShellTests` and `StopExecutorIsolationTests` opt INTO real
/// executor construction by additionally setting `AGENTJOBS_INTEGRATION=1`
/// in their suite setup. Production code never sets either env var, so the
/// guard is effectively no-op outside tests.
enum TestEnvBootstrap {
    static let _setOnce: Bool = {
        setenv("AGENTJOBS_TEST", "1", 1)
        return true
    }()
}

private let _bootstrap: Bool = TestEnvBootstrap._setOnce
