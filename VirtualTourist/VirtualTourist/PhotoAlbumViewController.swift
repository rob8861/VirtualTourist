//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Rob Fazio on 5/24/16.
//  Copyright © 2016 Rob Fazio. All rights reserved.
//

import UIKit
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, NSFetchedResultsControllerDelegate, UICollectionViewDataSource {
    
    let numOfCells = 10
    
    var pin: Pin!
    var photoCount = 0
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    // Keep the changes. We will keep track of insertions, deletions, and updates.
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    lazy var sharedContext: NSManagedObjectContext = {
       CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let request = NSFetchRequest(entityName: "Photo")
        request.predicate = NSPredicate(format: "pin == %@", self.pin)
        request.sortDescriptors = [NSSortDescriptor(key: "imagePath", ascending: true)]
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(PhotoAlbumViewController.cancel))
        
        // Perform the fetch
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        
        // Set the delegate to this view controller
        fetchedResultsController.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // reset the counter 
        photoCount = 0
        
        if pin.photos.isEmpty {
            
            for _ in 1...numOfCells {
                // create a new pin
                let photo = Photo(filePath: "", context: self.sharedContext)
                // associate the pin with photo using the inverse.
                photo.pin = self.pin
                // Save the context
                CoreDataStackManager.sharedInstance().saveContext()
            }
            
            // reload the collection view
            dispatch_async(dispatch_get_main_queue()) {
                self.collectionView.reloadData()
            }
            
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Lay out the collection view so that cells take up 1/3 of the width,
        // with no space in between.
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let width = floor(self.collectionView.frame.size.width/3)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancel() {
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func fetchNewCollection(sender: AnyObject) {
        
        let photos = fetchAllPhotos()
        for photo in photos {
            
            let path = self.fileInDocumentsDirectory(photo.imagePath!)
            deleteImageAtPath(path)
            
            photo.imagePath = ""
        }
        // reload the collection
        collectionView.reloadData()
        
    }
    
    
    // MARK: CollectionView Delegate
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as! PhotoAlbumCollectionCell
        
        if !cell.activityIndicator.isAnimating() {
            cell.activityIndicator.startAnimating()
        }
        
        configureCell(cell, photo: photo)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoAlbumCollectionCell
        
        cell.imageView.image = UIImage(named: "placeholder")
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        deleteImageAtPath(self.fileInDocumentsDirectory(photo.imagePath!))
        
        photo.imagePath = ""
        
        CoreDataStackManager.sharedInstance().saveContext()
        
    }
    
    // MARK: Fetch Results Controller Delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type{
            
        case .Insert:
            insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            deletedIndexPaths.append(indexPath!)
            break
        case .Update:
            updatedIndexPaths.append(indexPath!)
            break
        case .Move:
            //print("Move an item. We don't expect to see this in this app.")
            break
        }
        
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion:nil )
    }
    
    // MARK: Configure Cell
    
    private func configureCell(cell: PhotoAlbumCollectionCell, photo: Photo) {
        
        if let path = photo.imagePath {
            
            cell.imageView.image = UIImage(named: "placeholder")
            if path == "" {
                
                // download an image
                downloadImagesFromFlicker(cell, photo: photo)
            } else {
                
                let filePath = self.fileInDocumentsDirectory(path)
                if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
                    
                    let image = loadImageFromPath(path)
                    cell.imageView.image = image
                    cell.activityIndicator.stopAnimating()
                    
                    // increment the counter
                    photoCount += 1
                    if photoCount == numOfCells {
                        
                        // enable the new collection button
                        newCollectionButton.enabled = true
                    }
                    
                } else {
                    print("file not found at path: \(path)")
                }
                
            }
        }
    }
    
    // download flicker images
    private func downloadImagesFromFlicker(cell: PhotoAlbumCollectionCell, photo: Photo) {
        
        VTClient.sharedInstance().taskForGETMethod(pin.latitude, lon: pin.longitude) { (result, error) in
            
            if let error = error {
                print("Poster download error: \(error.localizedDescription)")
                return
            }
            
            guard let photosDictionary = result[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                print("Cannot find key '\(Constants.FlickrResponseKeys.Photos)' in \(result)")
                return
            }
            
            /* GUARD: Is the "photo" key in photosDictionary? */
            guard let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                print("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary)")
                return
            }
            
            if photosArray.count == 0 {
                print("No Photos Found. Search Again.")
                return
            } else {
                
                // pick a random photo
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                let photoDic = photosArray[randomPhotoIndex] as [String: AnyObject]
                
                /* GUARD: Does our photo have a key for 'url_m'? */
                guard let imageUrlString = photoDic[Constants.FlickrResponseKeys.MediumURL] as? String else {
                    print("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photo)")
                    return
                }
                
                let imageURL = NSURL(string: imageUrlString)
                
                let filePath = self.fileInDocumentsDirectory((imageURL?.lastPathComponent)!)
                photo.imagePath = (imageURL?.lastPathComponent)!
                
                if let imageData = NSData(contentsOfURL: imageURL!) {
                    
                    let image = UIImage(data: imageData)
                    
                    self.saveImage(image!, path: filePath)
                    
                    self.photoCount += 1
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.imageView.image = image
                        cell.activityIndicator.stopAnimating()
                        if self.photoCount == self.numOfCells {
                            self.newCollectionButton.enabled = true
                        }
                    }
                    
                } else {
                    print("Image does not exist at \(imageURL)")
                }
                
                // Save the context
                CoreDataStackManager.sharedInstance().saveContext()
            }
        }
    }
    
    // MARK: fetch all photos
    
    func fetchAllPhotos() -> [Photo] {
        
        let request = NSFetchRequest(entityName: "Photo")
        request.predicate = NSPredicate(format: "pin == %@", self.pin)
        
        do {
            return try self.sharedContext.executeFetchRequest(request) as! [Photo]
        } catch let error as NSError {
            print("\(error.localizedDescription)")
            return [Photo]()
        }
    }
    
    // MARK: saving and loading images
    
    // returns the path to the document directory
    func getDocumentsURL() -> NSURL {
        let documentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
        return documentsURL
    }
    
    // returns a path to a file
    func fileInDocumentsDirectory(filename: String) -> String {
        
        let fileURL = getDocumentsURL().URLByAppendingPathComponent(filename)
        return fileURL.path!
        
    }
    
    // save image to disk
    func saveImage (image: UIImage, path: String ) -> Bool{
        
        let pngImageData = UIImageJPEGRepresentation(image, 0.8)
        let result = pngImageData!.writeToFile(path, atomically: false)
        return result
        
    }
    
    // load the image from the disk
    func loadImageFromPath(path: String) -> UIImage? {
        
        let filePath = self.fileInDocumentsDirectory(path)
        
        let image = UIImage(contentsOfFile: filePath)
        
        if image == nil {
            
            print("missing image at: \(path)")
            return UIImage(named: "placeholder")
        }
        return image
        
    }
    
    func deleteImageAtPath(path: String) {
        
        if NSFileManager.defaultManager().fileExistsAtPath(path) {
            
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch let error as NSError {
                print("file delete error: \(error.localizedDescription)")
            }
        }
    }
}
