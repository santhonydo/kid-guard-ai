//
//  main.swift
//  KidGuardAIFilterExtension
//
//  Created by Anthony Do on 10/27/25.
//

import Foundation
import NetworkExtension
import os.log

let logger = Logger(subsystem: "com.kidguardai.KidGuardAI.KidGuardAIFilterExtension", category: "Main")

logger.info("Starting KidGuardAI Filter Extension")

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

logger.info("System extension mode started, entering dispatch main")
dispatchMain()
