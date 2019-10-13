//
//  CommandRegistry.swift
//  xcparse
//
//  Created by Alexander Botkin on 10/12/19.
//  Copyright © 2019 ChargePoint, Inc. All rights reserved.
//

import Basic
import Foundation
import SPMUtility

// This is cribbed form a great blog post on ArgumentParser
// https://www.enekoalonso.com/articles/handling-commands-with-swift-package-manager
struct CommandRegistry {
    private let parser: ArgumentParser
    private var commands: [Command] = []

    private var legacyScreenshots: OptionArgument<[PathArgument]>
    private var legacyXcov: OptionArgument<[PathArgument]>

    init(usage: String, overview: String) {
        parser = ArgumentParser(usage: usage, overview: overview)

        legacyScreenshots = parser.add(option: "--screenshots", shortName: "-s", kind: [PathArgument].self,
                                       strategy: .upToNextOption, usage: "Legacy screenshots", completion: .filename)
        legacyXcov = parser.add(option: "--xcov", shortName: "-x", kind: [PathArgument].self,
                                strategy: .upToNextOption, usage: "Legacy code covarge", completion: .filename)
    }

    mutating func register(command: Command.Type) {
        commands.append(command.init(parser: parser))
    }

    func run(arguments: [String] = Array(CommandLine.arguments.dropFirst())) {
        do {
            let parsedArguments = try parse(arguments)
            try process(arguments: parsedArguments)
        }
        catch let error as ArgumentParserError {
            print(error.description)
        }
        catch let error {
            print(error.localizedDescription)
        }
    }

    private func parse(_ arguments: [String] = Array(CommandLine.arguments.dropFirst())) throws -> ArgumentParser.Result {
        return try parser.parse(arguments)
    }

    private func processLegacyScreenshotCommand(arguments: ArgumentParser.Result) -> Bool {
        guard let legacyScreenshotPaths = arguments.get(self.legacyScreenshots) else {
            return false
        }
        if legacyScreenshotPaths.count < 2 || legacyScreenshotPaths.count > 2 {
            return false
        }

        do {
            let xcpParser = XCPParser()
            try xcpParser.extractScreenshots(xcresultPath: legacyScreenshotPaths[0].path.pathString,
                                             destination: legacyScreenshotPaths[1].path.pathString,
                                             options: AttachmentExportOptions(folderStructure: .legacy))

            return true
        } catch {
            return false
        }
    }

    private func processLegacyCodeCoverageCommand(arguments: ArgumentParser.Result) -> Bool {
        guard let legacyCodeCovPaths = arguments.get(self.legacyXcov) else {
            return false
        }
        if legacyCodeCovPaths.count < 2 || legacyCodeCovPaths.count > 2 {
            return false
        }

        do {
            let xcpParser = XCPParser()
            try xcpParser.extractCoverage(xcresultPath: legacyCodeCovPaths[0].path.pathString,
                                          destination: legacyCodeCovPaths[1].path.pathString)

            return true
        } catch {
            return false
        }
    }

    private func process(arguments: ArgumentParser.Result) throws {
        // Check to see if it's a legacy command
        if self.processLegacyScreenshotCommand(arguments: arguments) == true {
            return
        } else if self.processLegacyCodeCoverageCommand(arguments: arguments) == true {
            return
        }

        // We've determined it isn't a legacy command, so use new parsing
        guard let subparser = arguments.subparser(parser),
            let command = commands.first(where: { $0.command == subparser }) else {
            parser.printUsage(on: stdoutStream)
            return
        }
        try command.run(with: arguments)
    }

}
