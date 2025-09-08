import Base
import Types

// MARK: - Function Passes (operate on individual functions)

/// Base protocol for passes that operate on individual SSA functions
public protocol SSAFunctionPass {
    associatedtype Result
    
    /// Run the pass on a single SSA function
    func run(on function: inout SSAFunction) -> Result
}

/// A function pass that transforms/mutates an individual SSA function
public protocol SSAFunctionTransformPass: SSAFunctionPass where Result == Void {
    /// Transform the SSA function in place
    func transform(_ function: inout SSAFunction)
}

extension SSAFunctionTransformPass {
    public func run(on function: inout SSAFunction) -> Void {
        transform(&function)
    }
}

/// A function pass that analyzes an individual SSA function without modifying it
/// These passes should emit diagnostics directly rather than returning results
public protocol SSAFunctionAnalysisPass: SSAFunctionPass where Result == Void {
    /// Analyze the SSA function and emit diagnostics
    func analyze(_ function: SSAFunction, diagnostics: DiagnosticEngine)
}

extension SSAFunctionAnalysisPass {
    public func run(on function: inout SSAFunction) -> Void {
        // Analysis passes don't have access to diagnostics in the basic run method
        // They should be run through the pass manager instead
    }
}

// MARK: - Module Passes (operate on collections of functions)

/// Base protocol for passes that operate on modules (collections of functions)
public protocol SSAModulePass {
    associatedtype Result
    
    /// Run the pass on a list of SSA functions
    func run(on functions: inout [SSAFunction]) -> Result
}

/// A module pass that transforms a collection of SSA functions (can add/remove functions)
public protocol SSAModuleTransformPass: SSAModulePass where Result == Void {
    /// Transform the collection of SSA functions
    func transform(_ functions: inout [SSAFunction])
}

extension SSAModuleTransformPass {
    public func run(on functions: inout [SSAFunction]) -> Void {
        transform(&functions)
    }
}

/// A module pass that analyzes a collection of SSA functions without modifying them
public protocol SSAModuleAnalysisPass: SSAModulePass {
    /// Analyze the collection of SSA functions
    func analyze(_ functions: [SSAFunction]) -> Result
}

extension SSAModuleAnalysisPass {
    public func run(on functions: inout [SSAFunction]) -> Result {
        return analyze(functions)
    }
}

// MARK: - Pass Managers

/// Pass manager for function passes
public final class SSAFunctionPassManager {
    private var analysisResults: [String: Any] = [:]
    
    public init() {}
    
    /// Run a function analysis pass on a single function with diagnostics
    public func runAnalysis<P: SSAFunctionAnalysisPass>(_ pass: P, on function: inout SSAFunction, diagnostics: DiagnosticEngine) {
        pass.analyze(function, diagnostics: diagnostics)
    }
    
    /// Run a function transform pass on a single function
    public func runTransform<P: SSAFunctionTransformPass>(_ pass: P, on function: inout SSAFunction) {
        pass.run(on: &function)
    }
    
    /// Run a function transform pass on all functions in a collection
    public func runTransformOnAllFunctions<P: SSAFunctionTransformPass>(_ pass: P, on functions: inout [SSAFunction]) {
        for i in 0..<functions.count {
            pass.run(on: &functions[i])
        }
    }
    
    /// Run a function analysis pass on all functions in a collection
    public func runAnalysisOnAllFunctions<P: SSAFunctionAnalysisPass>(_ pass: P, on functions: inout [SSAFunction], diagnostics: DiagnosticEngine) {
        for i in 0..<functions.count {
            pass.analyze(functions[i], diagnostics: diagnostics)
        }
    }
    
    /// Get the result of a previously run analysis pass
    public func getAnalysisResult<T>(_ type: T.Type, passName: String) -> T? {
        return analysisResults[passName] as? T
    }
    
    /// Clear all stored analysis results
    public func clearAnalysisResults() {
        analysisResults.removeAll()
    }
}

/// Pass manager for module passes
public final class SSAModulePassManager {
    private var analysisResults: [String: Any] = [:]
    
    public init() {}
    
    /// Run a module analysis pass
    @discardableResult
    public func runAnalysis<P: SSAModuleAnalysisPass>(_ pass: P, on functions: inout [SSAFunction]) -> P.Result {
        let result = pass.run(on: &functions)
        let passName = String(describing: type(of: pass))
        analysisResults[passName] = result
        return result
    }
    
    /// Run a module transform pass
    public func runTransform<P: SSAModuleTransformPass>(_ pass: P, on functions: inout [SSAFunction]) {
        pass.run(on: &functions)
    }
    
    /// Get the result of a previously run analysis pass
    public func getAnalysisResult<T>(_ type: T.Type, passName: String) -> T? {
        return analysisResults[passName] as? T
    }
    
    /// Clear all stored analysis results
    public func clearAnalysisResults() {
        analysisResults.removeAll()
    }
}
