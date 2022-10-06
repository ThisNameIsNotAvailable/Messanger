//
//  LocationPickerViewController.swift
//  Messanger
//
//  Created by Alex on 06/10/2022.
//

import UIKit
import CoreLocation
import MapKit

final class LocationPickerViewController: UIViewController {

    public var completion: ((CLLocationCoordinate2D) -> Void)?
    private var coordinates: CLLocationCoordinate2D?
    private let locationManager = CLLocationManager()
    private var isPickable = true
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    init(coordinates: CLLocationCoordinate2D?) {
        self.coordinates = coordinates
        if coordinates != nil {
            isPickable = false
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendButtonTapped))
            map.isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
            locationManager.requestWhenInUseAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.startUpdatingLocation()
            map.showsUserLocation = true
            if let userLocation = locationManager.location?.coordinate {
                let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: 0.05, longitudinalMeters: 0.05)
                map.setRegion(region, animated: true)
            }
        } else {
            guard let coordinates = self.coordinates else {
                return
            }
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
            let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: 0.05, longitudinalMeters: 0.05)
            map.setRegion(region, animated: true)
        }
        view.addSubview(map)
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        for annotation in map.annotations {
            map.removeAnnotation(annotation)
        }
        // drop pin
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
    
    @objc func sendButtonTapped() {
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }

}
