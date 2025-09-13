import Base
import Types

// MARK: - Function Passes (operate on individual functions)

/// Base protocol for passes that operate on individual NIR functions
public protocol NIRFunctionPass {
    associatedtype Result

    /// Run the pass on a single NIR function
    func run(on function: inout NIRFunction) -> Result
}

/// A function pass that transforms/mutates an individual NIR function
public protocol NIRFunctionTransformPass: NIRFunctionPass where Result == Void {
    /// Transform the NIR function in place
    func transform(_ function: inout NIRFunction)
}

public extension NIRFunctionTransformPass {
    func run(on function: inout NIRFunction) {
        transform(&function)
    }
}

/// A function pass that analyzes an individual NIR function without modifying it
/// These passes should emit diagnostics directly rather than returning results
public protocol NIRFunctionAnalysisPass: NIRFunctionPass where Result == Void {
    /// Analyze the NIR function and emit diagnostics
    func analyze(_ function: NIRFunction, diagnostics: DiagnosticEngine)
}

public extension NIRFunctionAnalysisPass {
    func run(on _: inout NIRFunction) {
        // Analysis passes don't have access to diagnostics in the basic run method
        // They should be run through the pass manager instead
    }
}

// MARK: - Module Passes (operate on collections of functions)

/// Base protocol for passes that operate on modules (collections of functions)
public protocol NIRModulePass {
    associatedtype Result

    /// Run the pass on a list of NIR functions
    func run(on functions: inout [NIRFunction]) -> Result
}

/// A module pass that transforms a collection of NIR functions (can add/remove functions)
public protocol NIRModuleTransformPass: NIRModulePass where Result == Void {
    /// Transform the collection of NIR functions
    func transform(_ functions: inout [NIRFunction])
}

public extension NIRModuleTransformPass {
    func run(on functions: inout [NIRFunction]) {
        transform(&functions)
    }
}

/// A module pass that analyzes a collection of NIR functions without modifying them
public protocol NIRModuleAnalysisPass: NIRModulePass {
    /// Analyze the collection of NIR functions
    func analyze(_ functions: [NIRFunction]) -> Result
}

public extension NIRModuleAnalysisPass {
    func run(on functions: inout [NIRFunction]) -> Result {
        return analyze(functions)
    }
}

// MARK: - Pass Managers

/// Pass manager for function passes
public final class NIRFunctionPassManager {
    private var analysisResults: [String: Any] = [:]

    public init() {}

    /// Run a function analysis pass on a single function with diagnostics
    public func runAnalysis<P: NIRFunctionAnalysisPass>(_ pass: P, on function: inout NIRFunction, diagnostics: DiagnosticEngine) {
        pass.analyze(function, diagnostics: diagnostics)
    }

    /// Run a function transform pass on a single function
    public func runTransform<P: NIRFunctionTransformPass>(_ pass: P, on function: inout NIRFunction) {
        pass.run(on: &function)
    }

    /// Run a function transform pass on all functions in a collection
    public func runTransformOnAllFunctions<P: NIRFunctionTransformPass>(_ pass: P, on functions: inout [NIRFunction]) {
        for i in 0 ..< functions.count {
            pass.run(on: &functions[i])
        }
    }

    /// Run a function analysis pass on all functions in a collection
    public func runAnalysisOnAllFunctions<P: NIRFunctionAnalysisPass>(_ pass: P, on functions: inout [NIRFunction], diagnostics: DiagnosticEngine) {
        for i in 0 ..< functions.count {
            pass.analyze(functions[i], diagnostics: diagnostics)
        }
    }

    /// Get the result of a previously run analysis pass
    public func getAnalysisResult<T>(_: T.Type, passName: String) -> T? {
        return analysisResults[passName] as? T
    }

    /// Clear all stored analysis results
    public func clearAnalysisResults() {
        analysisResults.removeAll()
    }
}

/// Pass manager for module passes
public final class NIRModulePassManager {
    private var analysisResults: [String: Any] = [:]

    public init() {}

    /// Run a module analysis pass
    @discardableResult
    public func runAnalysis<P: NIRModuleAnalysisPass>(_ pass: P, on functions: inout [NIRFunction]) -> P.Result {
        let result = pass.run(on: &functions)
        let passName = String(describing: type(of: pass))
        analysisResults[passName] = result
        return result
    }

    /// Run a module transform pass
    public func runTransform<P: NIRModuleTransformPass>(_ pass: P, on functions: inout [NIRFunction]) {
        pass.run(on: &functions)
    }

    /// Get the result of a previously run analysis pass
    public func getAnalysisResult<T>(_: T.Type, passName: String) -> T? {
        return analysisResults[passName] as? T
    }

    /// Clear all stored analysis results
    public func clearAnalysisResults() {
        analysisResults.removeAll()
    }
}
