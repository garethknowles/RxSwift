//
//  PartialUpdatesViewController.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 6/8/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import CoreData

class PartialUpdatesViewController : ViewController {
    @IBOutlet weak var reloadTableViewOutlet: UITableView!
    @IBOutlet weak var partialUpdatesTableViewOutlet: UITableView!
    @IBOutlet weak var partialUpdatesCollectionViewOutlet: UICollectionView!
    
    var moc: NSManagedObjectContext!
    var child: NSManagedObjectContext!
    
    var timer: NSTimer? = nil
    
    static let initialValue: [HashableSectionModel<String, Int>] = [
        NumberSection(model: "section 1", items: [1, 2, 3]),
        NumberSection(model: "section 2", items: [4, 5, 6]),
        NumberSection(model: "section 3", items: [7, 8, 9]),
        NumberSection(model: "section 4", items: [10, 11, 12]),
        NumberSection(model: "section 5", items: [13, 14, 15]),
        NumberSection(model: "section 6", items: [16, 17, 18]),
        NumberSection(model: "section 7", items: [19, 20, 21]),
        NumberSection(model: "section 8", items: [22, 23, 24]),
        NumberSection(model: "section 9", items: [25, 26, 27]),
        NumberSection(model: "section 10", items: [28, 29, 30])
        ]
    
    
    static let firstChange: [HashableSectionModel<String, Int>]? = nil
    
    var generator = Randomizer(rng: PseudoRandomGenerator(4, 3), sections: initialValue)

    var sections = Variable([NumberSection]())
    
    let disposeBag = DisposeBag()
    
    func skinTableViewDataSource(dataSource: RxTableViewSectionedDataSource<NumberSection>) {
        dataSource.cellFactory = { (tv, ip, i) in
            let cell = tv.dequeueReusableCellWithIdentifier("Cell") as? UITableViewCell
                ?? UITableViewCell(style:.Default, reuseIdentifier: "Cell")
            
            cell.textLabel!.text = "\(i)"
            
            return cell
        }
        
        dataSource.titleForHeaderInSection = { [unowned dataSource] (section: Int) -> String in
            return dataSource.sectionAtIndex(section).model
        }
    }
    
    func skinCollectionViewDataSource(dataSource: RxCollectionViewSectionedDataSource<NumberSection>) {
        dataSource.cellFactory = { [unowned dataSource] (cv, ip, i) in
            let cell = cv.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: ip) as! NumberCell
            
            cell.value!.text = "\(i)"
            
            return cell
        }
        
        dataSource.supplementaryViewFactory = { [unowned dataSource] (cv, kind, ip) in
            let section = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: "Section", forIndexPath: ip) as! NumberSectionView
            
            section.value!.text = "\(dataSource.sectionAtIndex(ip.section).model)"
            
            return section
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        let generateCustomSize = true
        let runAutomatically = false
        
        // For UICollectionView, if another animation starts before previous one is finished, it will sometimes crash :(
        // It's not deterministic (because Randomizer generates deterministic updates), and if you click fast
        // It sometimes will and sometimes wont crash, depending on tapping speed.
        // I guess you can maybe try some tricks with timeout, hard to tell :( That's on Apple side.
        
        if generateCustomSize {
            let nSections = 10
            let nItems = 100
            
            var sections = [HashableSectionModel<String, Int>]()
            
            for i in 0 ..< nSections {
                sections.append(HashableSectionModel(model: "Section \(i + 1)", items: Array(i * nItems ..< (i + 1) * nItems)))
            }
            
            generator = Randomizer(rng: PseudoRandomGenerator(4, 3), sections: sections)
        }

        if runAutomatically {
            timer = NSTimer.scheduledTimerWithTimeInterval(0.6, target: self, selector: "randomize", userInfo: nil, repeats: true)
        }
        
        self.sections.next(generator.sections)
        
        let tvAnimatedDataSource = RxTableViewSectionedAnimatedDataSource<NumberSection>()
        //let cvAnimatedDataSource = RxCollectionViewSectionedReloadDataSource<NumberSection>()
        let cvAnimatedDataSource = RxCollectionViewSectionedAnimatedDataSource<NumberSection>()
        let reloadDataSource = RxTableViewSectionedReloadDataSource<NumberSection>()
        
        skinTableViewDataSource(tvAnimatedDataSource)
        skinTableViewDataSource(reloadDataSource)
        skinCollectionViewDataSource(cvAnimatedDataSource)
        
        let newSections = self.sections >- skip(1)
        
        let initialState = [Changeset.initialValue(self.sections.value)]
        
        // reactive data sources
        
        let updates = zip(self.sections, newSections) { (old, new) in
                return differentiate(old, new)
            }
            >- startWith(initialState)
            
        updates
            >- partialUpdatesTableViewOutlet.rx_subscribeWithReactiveDataSource(tvAnimatedDataSource)
            >- disposeBag.addDisposable

        self.sections
            >- reloadTableViewOutlet.rx_subscribeWithReactiveDataSource(reloadDataSource)
            >- disposeBag.addDisposable
        
        updates
            >- partialUpdatesCollectionViewOutlet.rx_subscribeWithReactiveDataSource(cvAnimatedDataSource)
            >- disposeBag.addDisposable
        
        // touches
        
        partialUpdatesCollectionViewOutlet.rx_itemSelected
            >- subscribeNext { [unowned self] i in
                println("Let me guess, it's .... It's \(self.generator.sections[i.section].items[i.item]), isn't it? Yeah, I've got it.")
            }
            >- disposeBag.addDisposable
        
        merge(from([partialUpdatesTableViewOutlet.rx_itemSelected, reloadTableViewOutlet.rx_itemSelected]))
            >- subscribeNext { [unowned self] i in
                println("I have a feeling it's .... \(self.generator.sections[i.section].items[i.item])?")
            }
            >- disposeBag.addDisposable
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.timer?.invalidate()
    }
    
    @IBAction func randomize() {
        generator.randomize()
        var values = generator.sections
       
        // useful for debugging
        if PartialUpdatesViewController.firstChange != nil {
            values = PartialUpdatesViewController.firstChange!
        }
        
        //println(values)
        
        sections.next(values)
    }
}