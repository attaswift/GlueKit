//
//  SelectOperatorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class Company {
    let name = Variable<String>("")
    let employees = Variable<Array<Person>>([])

    init(name: String) {
        self.name.value = name
    }
}

private class App {
    let name = Variable<String>("")
    let version = Variable<String>("")
    let developer: Variable<Company>

    init(name: String, version: String, developer: Company) {
        self.name.value = name
        self.version.value = version
        self.developer = Variable(developer)
    }
}

private class Person {
    let name = Variable<String>("")
    let favoriteApp: Variable<App>

    init(name: String, favoriteApp: App) {
        self.name.value = name
        self.favoriteApp = Variable(favoriteApp)
    }
}


class SelectOperatorTests: XCTestCase {
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
            adam: Person(name: "Adam Edgar Whatever", favoriteApp: apps.angryWombats),
            ben: Person(name: "Benjamin Smith", favoriteApp: apps.angryWombats),
            cecil: Person(name: "Cecil Testperson", favoriteApp: apps.angryWombats),
            david: Person(name: "David Sampleguy", favoriteApp: apps.angryWombats),
            emily: Person(name: "Emily von Fixture", favoriteApp: apps.cowLicker))

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
        let cowLickerDeveloperNames = apps.cowLicker.developer.select{$0.employees}.selectEach{$0.name}
        var r: [[String]] = []
        let connection = cowLickerDeveloperNames.values.connect { names in r.append(names) }

        XCTAssertEqual(cowLickerDeveloperNames.value, ["Adam Edgar Whatever", "David Sampleguy"])

        // David quits Cool Software and joins Banditware
        companies.coolSoftware.employees.value.removeAtIndex(1)
        companies.banditware.employees.value.append(people.david)
        XCTAssertEqual(cowLickerDeveloperNames.value, ["Adam Edgar Whatever"])

        // Cow Licker is sold to Banditware
        apps.cowLicker.developer.value = companies.banditware
        XCTAssertEqual(cowLickerDeveloperNames.value, ["Emily von Fixture", "David Sampleguy"])

        // David changes his name
        people.david.name.value = "Davey Sampleguy"
        XCTAssertEqual(cowLickerDeveloperNames.value, ["Emily von Fixture", "Davey Sampleguy"])

        XCTAssertEqual(r, [
            ["Adam Edgar Whatever", "David Sampleguy"],
            ["Adam Edgar Whatever"],
            ["Emily von Fixture", "David Sampleguy"],
            ["Emily von Fixture", "Davey Sampleguy"],
        ])
        connection.disconnect()
    }
}
