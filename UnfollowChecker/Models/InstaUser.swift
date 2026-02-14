//
//  InstaUser.swift
//  UnfollowChecker
//
//  Created by Giovanni Rizzolo on 13/02/26.
//

import Foundation

struct InstaUser: Hashable, Identifiable {
    let id: String
    init(username: String) { self.id = username }
    var username: String { id }
}
