//
//  StorageManager.swift
//  Messanger
//
//  Created by Alex on 30/09/2022.
//

import Foundation
import FirebaseStorage

/// Allows you to get, fetch and upload files to firebase storage
final class StorageManager {
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    private init() {}
    
    ///Upload picture to FirebaseStorage and returns completion with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) { [weak self] metaData, error in
            guard let strongSelf = self else {
                return
            }
            guard error == nil else {
                print("Failed to upload data to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            strongSelf.storage.child("images/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("failed to get picture url")
                    completion(.failure(StorageError.failedToGetDownloadedURL))
                    return
                }
                let urlString = url.absoluteString
                completion(.success(urlString))
            }
        }
    }
    
    /// Upload image that will be send in a conversation message
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil) { [weak self] metaData, error in
            guard error == nil else {
                print("Failed to upload data to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("failed to get picture url")
                    completion(.failure(StorageError.failedToGetDownloadedURL))
                    return
                }
                let urlString = url.absoluteString
                completion(.success(urlString))
            }
        }
    }
    
    /// Upload video that will be send in a conversation message
    public func uploadMessageVideo(with url: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
        // !Fails when uploading videos from library
        storage.child("message_videos/\(fileName)").putFile(from: url, metadata: nil) { [weak self] metaData, error in
            guard error == nil else {
                print("Failed to upload data to firebase for video \(error)")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("failed to get picture url")
                    completion(.failure(StorageError.failedToGetDownloadedURL))
                    return
                }
                let urlString = url.absoluteString
                completion(.success(urlString))
            }
        }
    }
    
    public func downoadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void)  {
        let reference = storage.child(path)
        reference.downloadURL { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageError.failedToGetDownloadedURL))
                return
            }
            completion(.success(url))
        }
    }
    
    public enum StorageError: Error {
        case failedToUpload
        case failedToGetDownloadedURL
    }
}
