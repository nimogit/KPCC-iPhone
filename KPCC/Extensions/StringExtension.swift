//
//  StringExtension.swift
//  KPCC
//
//  Created by Fuller, Christopher on 5/17/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

extension String {

    var range: NSRange {
        return NSMakeRange(0, characters.count)
    }

    var isEmailAddress: Bool {
        guard let dataDetector = try? NSDataDetector(types: NSTextCheckingType.Link.rawValue) else {
            return false
        }
        let mailtoString = "mailto:".stringByAppendingString(self)
        let matches = dataDetector.matchesInString(mailtoString, options: [], range: mailtoString.range)
        return (matches.first?.URL?.absoluteString == mailtoString)
    }

    var isPhoneNumber: Bool {
        guard let dataDetector = try? NSDataDetector(types: NSTextCheckingType.PhoneNumber.rawValue) else {
            return false
        }
        let matches = dataDetector.matchesInString(self, options: [], range: range)
        return (matches.first?.phoneNumber == self)
    }

    var URLPathEncodedString: String {
        let allowedCharacters = NSCharacterSet.URLPathAllowedCharacterSet()
        return stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacters)!
    }

    var URLQueryEncodedString: String {
        let allowedCharacters = NSCharacterSet.URLQueryAllowedCharacterSet()
        return stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacters)!
    }

}
