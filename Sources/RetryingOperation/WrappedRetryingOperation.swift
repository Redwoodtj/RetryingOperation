/*
Copyright 2018 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation



public protocol RetryableOperation : Operation {
	
	/* I’d like to add “where T : Self” so that clients of the protocol know ther're given an object kind of class Self,
	 * but I get an error (swift4.2):
	 *    Type ‘T’ constrainted to non-protocol, non-class type ‘Self’
	 *
	 * I could also remove the T type and set wrapper’s type to RetryableOperationWrapper<Self>,
	 * but this forces the clients of the protocol to be final, so it is not ideal either… */
	func retryHelpers<T>(from wrapper: RetryableOperationWrapper<T>) -> [RetryHelper]?
	
	/** Must return a valid retryable operation. You cannot return self here. */
	func operationForRetrying() throws -> Self
	
}


/**
 An operation that can run an operation conforming to the ``RetryableOperation`` protocol and
 retry the operation depending on the protocol implementation. */
public final class RetryableOperationWrapper<T> : RetryingOperation where T : RetryableOperation {
	
	public let originalBaseOperation: T
	public private(set) var currentBaseOperation: T
	
	/**
	 The queue on which the base operation(s) will run.
	 Do not set to the queue on which the retry operation wrapper runs unless you really know what you're doing.
	 
	 If `nil` (default), the base operation will not be launched in a queue. */
	public let baseOperationQueue: OperationQueue?
	
	/** If `< 0`, the operation is retried indefinitely. */
	public let maximumNumberOfRetries: Int
	
	public init(maximumNumberOfRetries maxRetry: Int = -1, baseOperation: T, baseOperationQueue queue: OperationQueue? = nil) {
		maximumNumberOfRetries = maxRetry
		
		originalBaseOperation = baseOperation
		currentBaseOperation = baseOperation
		
		baseOperationQueue = queue
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		/* No need to call super. */
		
		if isRetry {
			guard let op: T = try? currentBaseOperation.operationForRetrying() else {return baseOperationEnded()}
			assert(!op.isFinished && !op.isExecuting) /* Basic checks on operation to verify it is valid. */
			currentBaseOperation = op
		}
		
		if let q = baseOperationQueue {q.addOperation(currentBaseOperation)}
		else                          {currentBaseOperation.start()}
		currentBaseOperation.waitUntilFinished()
		
		let canRetry = (maximumNumberOfRetries < 0 || numberOfRetries! < maximumNumberOfRetries)
		self.baseOperationEnded(retryHelpers: canRetry ? currentBaseOperation.retryHelpers(from: self) : nil)
	}
	
	public override func cancelBaseOperation() {
		currentBaseOperation.cancel()
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
}
