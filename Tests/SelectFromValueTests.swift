//
//  SelectOperatorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class Entity {
    let int = Variable<Int>(0)
    let floats = ArrayVariable<Float>()

    init(_ int: Int, _ floats: [Float] = []) {
        self.int.value = int
        self.floats.value = floats
    }
}

class SelectFromValuesTests: XCTestCase {
    func testQueryAndUpdateSingleValue() {
        let e = Entity(42)
        let v = Variable<Entity>(e)
        let path = v.select{$0.int}

        XCTAssertEqual(path.value, 42)

        path.value = 23

        XCTAssertEqual(path.value, 23)
        XCTAssertEqual(e.int.value, 23)
    }

    func testObservingSingleValueChanges() {
        let e1 = Entity(1)
        let e2 = Entity(100)
        let v = Variable<Entity>(e1)
        let path = v.select{$0.int}

        var r = [Int]()
        let c = path.futureValues.connect { r.append($0) }

        e1.int.value = 2

        XCTAssertEqual(r, [2])

        path.value = 3

        XCTAssertEqual(r, [2, 3])

        v.value = e2

        XCTAssertEqual(r, [2, 3, 100])

        c.disconnect()
    }

    func testQueryAndUpdateArrayValue() {
        let e1 = Entity(0, [0.0])
        let e2 = Entity(2, [100.0])
        let v = Variable<Entity>(e1)
        let path: UpdatableArray<Float> = v.select{$0.floats}

        XCTAssertEqual(path.value, [0.0])

        path.value = [1.0, 2.0]

        XCTAssertEqual(path.value, [1.0, 2.0])
        XCTAssertEqual(e1.floats.value, [1.0, 2.0])

        path.remove(at: 1)

        let foo = ArrayVariable<Int>()
        foo.insert(1, at: 0)
        foo.insert(2, at: 1)
        foo.remove(at: 0)

        let upd = foo.updatableArray
        upd.insert(3, at: 0)
        upd.remove(at: 0)

        XCTAssertEqual(path.value, [1.0])
        XCTAssertEqual(e1.floats.value, [1.0])

        v.value = e2

        XCTAssertEqual(path.value, [100.0])
    }

    func testObservingArrayChanges() {
        let e1 = Entity(1)
        let e2 = Entity(100)
        let v = Variable<Entity>(e1)
        let path = v.select{$0.int}

        var r = [Int]()
        let c = path.futureValues.connect { r.append($0) }

        e1.int.value = 2

        XCTAssertEqual(r, [2])

        path.value = 3

        XCTAssertEqual(r, [2, 3])

        v.value = e2
        
        XCTAssertEqual(r, [2, 3, 100])
        
        c.disconnect()
    }

}

private class Company: CustomStringConvertible {
    let name = Variable<String>("")
    let employees = ArrayVariable<Person>([])
    let apps = ArrayVariable<App>([])

    init(name: String) {
        self.name.value = name
    }

    var description: String { return self.name.value }

    func fire(_ employee: Person) {
        if let index = employees.value.index(where: { $0 === self }) {
            employees.remove(at: index)
            print("\(employee) has been fired from \(self).")
        }
    }

    func sell(_ app: App, to buyer: Company) {
        if let index = apps.value.index(where: { $0 === app }) {
            print("\(self) has sold \(app) to \(buyer)")
            app.developer.value = buyer
            buyer.apps.append(app)
            apps.remove(at: index)
        }
    }
}

private class App: CustomStringConvertible {
    let name = Variable<String>("")
    let version = Variable<String>("")
    let developer: UnownedVariable<Company>

    init(name: String, version: String, developer: Company) {
        self.name.value = name
        self.version.value = version
        self.developer = UnownedVariable(developer)

        developer.apps.append(self)
    }

    var description: String { return self.name.value }
}

private class Person: CustomStringConvertible {
    let name = Variable<String>("")
    let favoriteApp: Variable<App>
    let employer: WeakVariable<Company>

    init(name: String, favoriteApp: App, employer: Company?) {
        self.name.value = name
        self.favoriteApp = Variable(favoriteApp)
        self.employer = WeakVariable(employer)

        employer?.employees.append(self)
    }

    var description: String { return self.name.value }

    func quit() {
        if let employer = self.employer.value {
            if let index = employer.employees.value.index(where: { $0 === self }) {
                employer.employees.remove(at: index)
            }
            self.employer.value = nil
            print("\(self) has quit from \(employer).")
        }
    }
}

class SelectFromValueTestsExamples: XCTestCase {
    private struct Companies {
        let appNinja: Company
        let banditware: Company
        let coolSoftware: Company
    }
    private struct Apps {
        let angryWombats: App
        let baconCrush: App
        let cowLicker: App
    }
    private struct People {
        let adam: Person
        let ben: Person
        let cecil: Person
        let david: Person
        let emily: Person
    }
    private var companies: Companies!
    private var apps: Apps!
    private var people: People!

    override func setUp() {
        // Reset fixtures
        companies = Companies(
            appNinja: Company(name: "App Ninja"),
            banditware: Company(name: "Banditware"),
            coolSoftware: Company(name: "Cool Software"))
        apps = Apps(
            angryWombats: App(name: "Angry Wombats", version: "2.1.23", developer: companies.coolSoftware),
            baconCrush: App(name: "Bacon Crush", version: "3.2.0", developer: companies.appNinja),
            cowLicker: App(name: "Cow Licker", version: "1.0.0", developer: companies.coolSoftware))
        people = People(
            adam: Person(name: "Adam Edgar Whatever", favoriteApp: apps.angryWombats, employer: companies.coolSoftware),
            ben: Person(name: "Benjamin Smith", favoriteApp: apps.angryWombats, employer: companies.appNinja),
            cecil: Person(name: "Cecil Testperson", favoriteApp: apps.angryWombats, employer: companies.appNinja),
            david: Person(name: "David Sampleguy", favoriteApp: apps.angryWombats, employer: companies.coolSoftware),
            emily: Person(name: "Emily von Fixture", favoriteApp: apps.cowLicker, employer: companies.banditware))

        companies.appNinja.employees.value = [people.ben, people.cecil]
        companies.banditware.employees.value = [people.emily]
        companies.coolSoftware.employees.value = [people.adam, people.david]
    }


    func testSelectorPathValueUpdatesAfterChanges() {
        let adamsFavoriteAppsDevelopersName = people.adam.favoriteApp.select { $0.developer }.select { $0.name }
        XCTAssertEqual(adamsFavoriteAppsDevelopersName.value, "Cool Software")

        // Company changes its name
        companies.coolSoftware.name.value = "Cool Software, Inc."
        XCTAssertEqual(adamsFavoriteAppsDevelopersName.value, "Cool Software, Inc.")

        // Cool Software sells Angry Wombat app to App Ninja
        apps.angryWombats.developer.value = companies.appNinja
        XCTAssertEqual(adamsFavoriteAppsDevelopersName.value, "App Ninja")

        // Adam changes his mind
        people.adam.favoriteApp.value = apps.baconCrush
        XCTAssertEqual(adamsFavoriteAppsDevelopersName.value, "App Ninja") // No change

        // Adam changes his mind again
        people.adam.favoriteApp.value = apps.cowLicker
        XCTAssertEqual(adamsFavoriteAppsDevelopersName.value, "Cool Software, Inc.")

        // App Ninja changes its name
        companies.appNinja.name.value = "App Walrus"
        XCTAssertEqual(adamsFavoriteAppsDevelopersName.value, "Cool Software, Inc.") // No change
    }

    func testSelectorPathSendsNewValuesAfterChanges() {
        let adamsFavoriteAppsDevelopersName = people.adam.favoriteApp.select { $0.developer }.select { $0.name }
        var r = [String]()
        let connection = adamsFavoriteAppsDevelopersName.values.connect { r.append($0) }

        // Company changes its name
        companies.coolSoftware.name.value = "Cool Software, Inc." // --> "Cool Software, Inc."

        // Cool Software sells app to App Ninja
        apps.angryWombats.developer.value = companies.appNinja // --> "App Ninja"

        // Adam changes his mind
        people.adam.favoriteApp.value = apps.baconCrush // --> "App Ninja" (duplicate)

        // Adam changes his mind again
        people.adam.favoriteApp.value = apps.cowLicker // --> "Cool Software, Inc."

        // App Ninja changes its name
        companies.appNinja.name.value = "App Walrus" // Nothing is sent

        XCTAssertEqual(r, ["Cool Software", "Cool Software, Inc.", "App Ninja", "App Ninja", "Cool Software, Inc."])
        connection.disconnect()
    }

    func testSelectorPathCanBeUsedToUpdateValue() {
        let adamsFavoriteAppsDevelopersName = people.adam.favoriteApp.select { $0.developer }.select { $0.name }

        XCTAssertEqual(companies.coolSoftware.name.value, "Cool Software")

        // "setValue:forKeyPath:"
        adamsFavoriteAppsDevelopersName.value = "Test Software"
        XCTAssertEqual(companies.coolSoftware.name.value, "Test Software")

        people.adam.favoriteApp.value = apps.baconCrush
        XCTAssertEqual(adamsFavoriteAppsDevelopersName.value, "App Ninja")

        adamsFavoriteAppsDevelopersName.value = "Test Ninja"
        XCTAssertEqual(companies.appNinja.name.value, "Test Ninja")
    }

    func testArraySelector() {
        let cowLickerDeveloperNames: ObservableArray<String> = apps.cowLicker.developer.select{$0.employees}.selectEach{$0.name}

        var r: [[String]] = []
        let connection = cowLickerDeveloperNames.futureChanges.connect { changes in r.append(cowLickerDeveloperNames.value) }

        XCTAssertEqual(cowLickerDeveloperNames.value, ["Adam Edgar Whatever", "David Sampleguy"])

        // David quits Cool Software and joins Banditware
        companies.coolSoftware.employees.value.remove(at: 1)
        companies.banditware.employees.value.append(people.david)
        XCTAssertEqual(cowLickerDeveloperNames.value, ["Adam Edgar Whatever"])

        // Cow Licker is sold to Banditware
        apps.cowLicker.developer.value = companies.banditware
        XCTAssertEqual(cowLickerDeveloperNames.value, ["Emily von Fixture", "David Sampleguy"])

        // David changes his name
        people.david.name.value = "Davey Sampleguy"
        XCTAssertEqual(cowLickerDeveloperNames.value, ["Emily von Fixture", "Davey Sampleguy"])

        XCTAssertEqual(r, [
            ["Adam Edgar Whatever"],
            ["Emily von Fixture", "David Sampleguy"],
            ["Emily von Fixture", "Davey Sampleguy"],
        ])
        connection.disconnect()
    }
}
