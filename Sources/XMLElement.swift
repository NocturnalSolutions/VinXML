//
//  XMLElement.swift
//  VinXML
//
//  Created by Maurice Parker on 1/31/17.
//  Copyright © 2017 Vincode. All rights reserved.
//

import libxml2

public class XMLElement: XMLXPath, XMLVisitorHost, Equatable {

    public weak var doc: XMLDocument?
    public weak var parent: XMLElement?
    var nodePtr: xmlNodePtr!
    
    public var name: String? {
        get {
            if let name = nodePtr.pointee.name {
                return String(cString: name)
            } else {
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                return
            }
            xmlNodeSetName(nodePtr, newValue.xmlChars)
        }
    }
    
    public var content: String? {
        let content = xmlNodeGetContent(nodePtr)
        defer { xmlFree(content) }
        if content != nil {
            return String(cString: content!).trimmed()
        } else {
            return nil
        }
    }
    
    public var text: String? {
        let text = xmlNodeListGetString(doc?.docPtr, nodePtr.pointee.children, 1)
        defer { xmlFree(text) }
        if text != nil {
            return String(cString: text!).trimmed()
        } else {
            return nil
        }
    }
    
    public var hasContent: Bool {
        return content != nil
    }
    
    public var hasText: Bool {
        return text != nil
    }
    
    public var raw: String? {
        if let buffer = xmlBufferCreate() {
            xmlNodeDump(buffer, doc!.docPtr, nodePtr, 0, 0)
            defer { xmlBufferFree(buffer) }
            return String(cString: buffer.pointee.content)
        } else {
            return nil
        }
    }
    
    public lazy var siblings: XMLElements = XMLElements(root: self)
    public lazy var children: XMLElements = XMLElements(doc: self.doc, parent: self)
    public lazy var attributes: XMLAttributes = XMLAttributes(parent: self)
    public lazy var type: XMLElementType = XMLElementType(rawValue: Int(self.nodePtr.pointee.type.rawValue))!
   
    public init?(doc: XMLDocument?, parent: XMLElement?, nodePtr: xmlNodePtr!) {
        self.doc = doc
        self.parent = parent
        self.nodePtr = nodePtr
        if nodePtr == nil {
            return nil
        }
    }
    
    public func query(xpath: String) throws -> [XMLElement] {
        
        guard let xPathObj = xmlXPathNodeEval(nodePtr, xpath.xmlChars, doc?.pathCtxPtr) else { return [] }
        defer { xmlXPathFreeObject(xPathObj) }
        
        guard let nodes = xPathObj.pointee.nodesetval else { return [] }
        
        let nodePtrs = UnsafeBufferPointer(start: nodes.pointee.nodeTab, count: Int(nodes.pointee.nodeNr))
        let xnodes = nodePtrs.flatMap { XMLElement.init(doc: doc, parent: nil, nodePtr: $0) }
        
        return xnodes
        
    }
    
    public func remove() throws {
        xmlUnlinkNode(nodePtr)
        xmlFreeNode(nodePtr!)
    }

    //MARK: Useful traversal functions.

    public func hasChildren() -> Bool {
        return !self.children.isEmpty
    }
    
    public func children(forName name: String) -> [XMLElement] {
        return self.children.filter { $0.name == name }
    }
    
    public func firstChild() -> XMLElement? {
        return self.children.first
    }

    public func firstChild(forName name: String) -> XMLElement? {
        return self.children(forName: name).first
    }

    public func nextSibling() -> XMLElement? {
        if let nextNodePtr = xmlNextElementSibling(nodePtr) {
            return XMLElement.init(doc: doc, parent: parent, nodePtr: nextNodePtr)
        }
        return nil
    }
    
    static public func == (lhs: XMLElement, rhs: XMLElement) -> Bool {
        return lhs.nodePtr == rhs.nodePtr
    }
    
    // MARK: Visitor
    public func host(visitor: XMLVisitor) throws {
        if try visitor.visit(host: self) {
            try children.forEach() { element in
                try element.host(visitor: visitor)
            }
        }
    }
    
}
