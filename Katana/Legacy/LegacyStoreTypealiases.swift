//
//  StoreTypealiases.swift
//  Katana
//
//  Copyright © 2016 Bending Spoons.
//  Distributed under the MIT License.
//  See the LICENSE file for more information.

import Foundation

public typealias StoreMiddlewareNext = (_: Dispatchable) -> Void

/**
 Typealias for the `Store` middleware. Note that the first part of the middleware
 (the one with `getState` and `dispatch`) is immediately invoked when the store is created
 */
public typealias StoreMiddleware =
  (_ getState: @escaping () -> State, _ dispatch: @escaping StoreDispatch) ->
  (_ next: @escaping StoreMiddlewareNext) ->
  (_ dispatchable: Dispatchable) -> ()

/// Typealias for the `Store` dispatch function
public typealias StoreDispatch = (_: Action) -> ()

public func middlewareToInterceptor(_ middleware: @escaping StoreMiddleware) -> StoreInterceptor {
  return { getState, dispatch in
    
    let legacyDispatch: StoreDispatch = { dispatchable in
      let _ = dispatch(dispatchable)
    }
    
    let initialisedMiddleware = middleware(getState, legacyDispatch)
    
    return { next in
      
      let legacyNext: StoreMiddlewareNext = { action in
        try? next(action)
      }
      
      return { dispatchable in
        initialisedMiddleware(legacyNext)(dispatchable)
      }
    }
  }
}