//
//  FilterDataProvider.swift
//  KidGuardAIFilterExtension
//
//  Created by Anthony Do on 10/27/25.
//

import NetworkExtension
import os.log

class FilterDataProvider: NEFilterDataProvider {
    
    private let logger = Logger(subsystem: "com.kidguardai.KidGuardAI.KidGuardAIFilterExtension", category: "FilterDataProvider")

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting filter data provider")
        // Initialize the filter
        completionHandler(nil)
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping filter data provider with reason: \(reason.rawValue)")
        // Clean up filter resources
        completionHandler()
    }
    
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        logger.debug("Handling new flow: \(flow.url?.absoluteString ?? "unknown")")
        
        // For now, allow all flows
        // In a real implementation, you would check against your filtering rules
        return .allow()
    }
    
    override func handleInboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
        logger.debug("Handling inbound data from flow: \(flow.url?.absoluteString ?? "unknown")")
        
        // For now, allow all data
        return .allow()
    }
    
    override func handleOutboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
        logger.debug("Handling outbound data from flow: \(flow.url?.absoluteString ?? "unknown")")
        
        // For now, allow all data
        return .allow()
    }
}
