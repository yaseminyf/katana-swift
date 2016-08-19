//
//  Node.swift
//  Katana
//
//  Created by Luca Querella on 09/08/16.
//  Copyright © 2016 Bending Spoons. All rights reserved.
//

import UIKit

public protocol AnyNode: class, ReferenceViewProvider {
  var description : AnyNodeDescription { get }
  var children : [AnyNode]? { get }
  func render(container: RenderContainer)
  func update(description: AnyNodeDescription) throws
}

public class Node<Description:NodeDescription>: PlasticNode, AnyNode {
  public private(set) var children : [AnyNode]?
  
  var state : Description.State
  var typedDescription : Description
  
  private var container: RenderContainer?
  weak var parentNode: AnyNode?
  
  public var description: AnyNodeDescription {
    get {
      return self.typedDescription
    }
  }
  
  public init(description: Description, parentNode: AnyNode?) {
    self.typedDescription = description
    self.state = Description.initialState
    self.parentNode = parentNode
    
    let update = { [weak self] (state: Description.State) -> Void in
      self?.update(state: state)
    }

    let children  = Description.render(props: self.typedDescription.props,
                                       state: self.state,
                                       update: update)
    
    self.children = self.applyLayout(to: children)
          .map { $0.node(parentNode: self) }
  }
  
  func update(state: Description.State)  {
    self.update(state: state, description: self.typedDescription)
  }
  
  public func update(description: AnyNodeDescription) throws {
    let description = description as! Description
    self.update(state: self.state, description: description)
  }
  
  func update(state: Description.State, description: Description) {
    guard let children = self.children else {
      fatalError("update should not be called at this time")
    }
    
    let sameProps = self.typedDescription.props == description.props
    let sameState = self.state == state
    
    if (sameProps && sameState) {
      return
    }
    
    self.typedDescription = description
    self.state = state
    
    var currentChildren : [Int:[(node: AnyNode, index: Int)]] = [:]
    
    for (index,child) in children.enumerated() {
      let key = child.description.replaceKey()
      let value = (node: child, index: index)
      
      if currentChildren[key] == nil {
        currentChildren[key] = [value]
      } else {
        currentChildren[key]!.append(value)
      }
    }


    let update = { [weak self] (state: Description.State) -> Void in
      self?.update(state: state)
    }
    
    var newChildren = Description.render(props: self.typedDescription.props,
                                         state: self.state,
                                         update: update)
    
    newChildren = self.applyLayout(to: newChildren)
    
    var nodes : [AnyNode] = []
    var viewIndex : [Int] = []
    var nodesToRender : [AnyNode] = []
    
    for newChild in newChildren {
      let key = newChild.replaceKey()
      
      if currentChildren[key]?.count > 0 {
        let replacement = currentChildren[key]!.removeFirst()
        assert(replacement.node.description.replaceKey() == newChild.replaceKey())
        
        try! replacement.node.update(description: newChild)
        
        nodes.append(replacement.node)
        viewIndex.append(replacement.index)
        
      } else {
        //else create a new node
        let node = newChild.node(parentNode: self)
        viewIndex.append(children.count + nodesToRender.count)
        nodes.append(node)
        nodesToRender.append(node)
      }
    }
    
    self.children = nodes
    
    self.updateRender(applyProps: (!(sameProps && sameState)),
                      childrenToRender: nodesToRender,
                      viewIndexes: viewIndex)
  }
  
  public func render(container: RenderContainer) {
    guard let children = self.children else {
      fatalError("render cannot be called at this time")
    }
    
    if (self.container != nil)  {
      fatalError("node can be render on a single View")
    }
    
    self.container = container.add { Description.NativeView() }
    
    self.container?.update { view in
      Description.applyPropsToNativeView(props: self._description.props,
                             state: self.state,
                             view: view as! Description.NativeView,
                             update: self.update)
    }
    
    children.forEach { $0.render(container: self.container!) }
  }
  
  
  public func updateRender(applyProps: Bool, childrenToRender: [AnyNode], viewIndexes: [Int]) {
    guard let container = self.container else {
      return
    }
    
    assert(viewIndexes.count == self.children?.count)
    
    if (applyProps)  {
      container.update { view in
        Description.applyPropsToNativeView(props: self._description.props,
                               state: self.state,
                               view: view as! Description.NativeView,
                               update: self.update)
        
      }
    }
    
    childrenToRender.forEach { node in
      return node.render(container: container)
    }
    
    var currentSubviews : [RenderContainerChild?] =  container.children().map { $0 }
    let sorted = viewIndexes.isSorted
    
    for viewIndex in viewIndexes {
      let currentSubview = currentSubviews[viewIndex]!
      if (!sorted) {
        container.bringToFront(child: currentSubview)
      }
      currentSubviews[viewIndex] = nil
    }
    
    for view in currentSubviews {
      if let viewToRemove = view {
        self.container?.remove(child: viewToRemove)
      }
    }
  }
}