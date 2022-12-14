//
//  DatabaseManager.swift
//  Messanger
//
//  Created by Alex on 28/09/2022.
//

import Foundation
import FirebaseDatabase
import MessageKit
import CoreLocation

/// Manager object to read and write data to real time database
final class DatabaseManager {
    
    /// Shared intsance of class
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    private init() {}
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    
    /// Returns a dictionary node at child path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
}
//MARK: - Account managment
extension DatabaseManager {
    
    /// Checks if user exists for given email
    // Parameters
    /// - `email`:    Target email to be checked
    /// - `completion`:   Async closure to return with result
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard let _ = snapshot.value as? [String : Any] else {
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    ///Insert new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ]) { [weak self] error, _ in
            guard let strongSelf = self else {
                return
            }
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            strongSelf.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersCollection = snapshot.value as? [[String : String]] {
                    let newElement = [
                        "name" : user.firstName + " " + user.lastName,
                        "email" : user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    strongSelf.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                } else {
                    let newCollection: [[String : String]] = [
                        [
                            "name" : user.firstName + " " + user.lastName,
                            "email" : user.safeEmail
                        ]
                    ]
                    strongSelf.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                }
            }
            completion(true)
        }
    }
    
    /// Gets all users from database
    public func getAllUsers(completion: @escaping (Result<[[String : String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String : String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
    
}

//MARK: - Sending messages / conversations
extension DatabaseManager {
    
    /// Create a new conversation woth target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, name: String, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child(safeEmail)
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
                return
            }
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateformatter.string(from: messageDate)
            var message = ""
            let conversationID = "conversation_\(firstMessage.messageId)"
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let newConversationData: [String: Any] = [
                "id" : conversationID,
                "other_user_email" : otherUserEmail,
                "name" : name,
                "latest_message" : [
                    "date" : dateString,
                    "is_read" : false,
                    "message" : message
                ] as [String: Any]
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id" : conversationID,
                "other_user_email" : safeEmail,
                "name" : currentName,
                "latest_message" : [
                    "date" : dateString,
                    "is_read" : false,
                    "message" : message
                ] as [String: Any]
            ]
            // Update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                if var conversations = snapshot.value as? [[String : Any]] {
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String : Any]] {
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID, name: name, firstMessage: firstMessage, completion: completion)
                }
            } else {
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID, name: name, firstMessage: firstMessage, completion: completion)
                }
            }
        })
    }
    
    private func finishCreatingConversation(conversationID: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateformatter.string(from: messageDate)
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        let messageObject: [String : Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name" : name
        ]
        let value: [String: Any] = [
            "messages": [
                messageObject
            ]
        ]
        database.child("\(conversationID)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Fetches and returns all conversations for the user with passed email
    public func getAllConversation(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations: [Conversation] = value.compactMap { dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let dateSent = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    
                    return nil
                }
                let latestMessageObject = LatestMessage(date: dateSent, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            }
            completion(.success(conversations))
        })
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap { dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageId = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateformatter.date(from: dateString),
                      let type = dictionary["type"] as? String else {
                    return nil
                }
                var kind: MessageKind?
                if type == "photo" {
                    guard let url = URL(string: content),
                          let placeholder = UIImage(systemName: "x.circle") else {
                        return nil
                    }
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                }else if type == "video" {
                    guard let url = URL(string: content),
                          let placeholder = UIImage(named: "video_placeholder") else {
                        return nil
                    }
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                } else if type == "location" {
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else {
                        return nil
                    }
                    
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                    kind = .location(location)
                } else {
                    kind = .text(content)
                }
                
                guard let finalKind = kind else {
                    return nil
                }
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageId, sentDate: date, kind: finalKind)
            }
            completion(.success(messages))
        })
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, message: Message, name: String, completion: @escaping (Bool) -> Void) {
        // add new message to messages
        
        // update sender latest message
        // update recipien latest message
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String : Any]] else {
                completion(false)
                return
            }
            
            var messageString = ""
            switch message.kind {
            case .text(let messageText):
                messageString = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    messageString = targetURLString
                }
                break
            case .video(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    messageString = targetURLString
                }
                break
            case .location(let locationData):
                let location = locationData.location
                messageString = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let messageDate = message.sentDate
            let dateString = ChatViewController.dateformatter.string(from: messageDate)
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            let messageObject: [String : Any] = [
                "id": message.messageId,
                "type": message.kind.messageKindString,
                "content": messageString,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name" : name
            ]
            
            currentMessages.append(messageObject)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "message": messageString,
                        "is_read": false
                    ]
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        var targetConversation: [String: Any]?
                        var position = 0
                        for conversationDictionary in currentUserConversations {
                            if let currentId = conversationDictionary["id"] as? String,
                               currentId == conversation {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id" : conversation,
                                "other_user_email" : DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "name" : name,
                                "latest_message" : updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    } else {
                        let newConversationData: [String: Any] = [
                            "id" : conversation,
                            "other_user_email" : DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name" : name,
                            "latest_message" : updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        // update latest message for recipient
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "message": messageString,
                                "is_read": false
                            ]
                            var databaseEntryConversations = [[String: Any]]()
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                                return
                            }
                            if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                var targetConversation: [String: Any]?
                                var position = 0
                                for conversationDictionary in otherUserConversations {
                                    if let currentId = conversationDictionary["id"] as? String,
                                       currentId == conversation {
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }
                                if var targetConversation = targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                }else {
                                    //failed to find in current collection
                                    let newConversationData: [String: Any] = [
                                        "id" : conversation,
                                        "other_user_email" : DatabaseManager.safeEmail(emailAddress: currentUserEmail),
                                        "name" : currentName,
                                        "latest_message" : updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }
                                
                            } else {
                                let newConversationData: [String: Any] = [
                                    "id" : conversation,
                                    "other_user_email" : DatabaseManager.safeEmail(emailAddress: currentUserEmail),
                                    "name" : currentName,
                                    "latest_message" : updatedValue
                                ]
                                databaseEntryConversations = [
                                    newConversationData
                                ]
                            }
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            }
                        }
                    }
                })
                
            }
        })
    }
    
    public func deleteConversation(conversationId: String, completion: @escaping (Bool)  -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String, id == conversationId {
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations) { error, _ in
                    guard error == nil else {
                        print("Failed to write new conversation")
                        completion(false)
                        return
                    }
                    completion(true)
                }
            }
        }
    }
    
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        let safeReipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        
        database.child("\(safeReipientEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            if let conversation = collection.first(where: { convo in
                guard let targetSender = convo["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSender
            }) {
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        }
    }
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
