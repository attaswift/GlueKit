//
//  SampleModel.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-11.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation
import GlueKit

public class Account: CustomDebugStringConvertible {
    public let name: Variable<String>
    public let email: Variable<String>

    public init(name: String, email: String) {
        self.name = Variable(name)
        self.email = Variable(email)
    }

    public var debugDescription: String {
        return "Account(name: \"\(name.value)\", email: \"\(email.value)\")"
    }
}

public class Issue: CustomDebugStringConvertible {
    public let identifier: Variable<String>
    public let owner: Variable<Account>
    public let isOpen: Variable<Bool>
    public let created: Variable<NSDate>

    public init(identifier: String, owner: Account, isOpen: Bool = true, created: NSDate = NSDate()) {
        self.identifier = Variable(identifier)
        self.owner = Variable(owner)
        self.isOpen = Variable(isOpen)
        self.created = Variable(created)
    }

    public var debugDescription: String {
        let open = isOpen.value ? "open" : "closed"
        return "Issue(id: \"\(identifier.value)\", owner: \"\(owner.value.name.value)\", \(open), created: \(created.value)"
    }
}

public class Project: CustomDebugStringConvertible {
    public let name: Variable<String>
    public let issues: ArrayVariable<Issue> = []

    private var nextIssueNumber: Int = 0
    private var issueIdentifierPrefix: String

    public init(name: String, issueIdentifierPrefix: String) {
        self.name = Variable(name)
        self.issueIdentifierPrefix = issueIdentifierPrefix
    }

    public func createNewIssue(owner: Account) -> Issue {
        let issue = Issue(identifier: issueIdentifierPrefix + String(format: "%04d", nextIssueNumber), owner: owner)
        nextIssueNumber += 1
        issues.append(issue)
        return issue
    }

    public var debugDescription: String {
        return "Project(name: \"\(name.value)\" with \(issues.count) issues)"
    }
}

public class Document: CustomDebugStringConvertible {
    public let accounts: ArrayVariable<Account> = []
    public let projects: ArrayVariable<Project> = []

    public init() {
    }

    public func randomAccount() -> Account {
        let index: Int = Int(arc4random_uniform(UInt32(accounts.count)))
        return accounts[index]
    }

    public var debugDescription: String {
        return "Document with \(accounts.count) accounts and \(projects.count) projects"
    }
}

let sampleAccounts = [ // name -> email
    "Edmund": "edmund@example.org",
    "Sodoff": "baldrick@example.org",
    "George": "george@example.org",
    "Melchie": "melchett@example.org",
    "Dorothy": "dorothy@example.com",
    "Rose": "rose@example.com",
    "Blanche": "blanche@example.com",
    "Sophia": "sophia@example.com",
]

let sampleProjects = [ // name -> issue identifier prefix
    "GlueKit": "GLK-",
    "FunKit": "FUN-",
    "BugKit": "BUG-",
]

public func createEmptyDocument() -> Document {
    let document = Document()
    return document
}

public func createSampleDocument() -> Document {
    let document = createEmptyDocument()

    // Create accounts.
    for (name, email) in sampleAccounts {
        let account = Account(name: name, email: email)
        document.accounts.append(account)
    }

    // Create projects.
    for (name, prefix) in sampleProjects {
        let project = Project(name: name, issueIdentifierPrefix: prefix)
        document.projects.append(project)
    }

    // Create random issues.
    for project in document.projects {
        for _ in 1...(1 + arc4random_uniform(99)) {
            project.createNewIssue(document.randomAccount())
        }
    }
    return document
}