//
//  ViewController.swift
//  Heater
//
//  Created by Peter Scott on 30/04/2016.
//  Copyright © 2016 Peter Scott. All rights reserved.
//

import UIKit
import ParticleDeviceSetupLibrary
import ParticleSDK

class ViewController: UIViewController, SparkSetupMainControllerDelegate {
    
    func hullo(name: String) {
        print("Hullo from \(name) ")
    }
    
    func sparkSetupViewController(controller: SparkSetupMainController!, didFinishWithResult result: SparkSetupMainControllerResult, device: SparkDevice!) {
        print("result: \(result), and device: \(device)")
    }
    
    let loginGroup : dispatch_group_t = dispatch_group_create()
    let deviceGroup : dispatch_group_t = dispatch_group_create()
    let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
    
    let deviceName = "woolyHeater"
    let username = "peeda@comcen.com.au"
    let password = "f00kin-k00nt"
    
    var myPhoton : SparkDevice? = nil
    var myEventId : AnyObject?

    @IBOutlet weak var HulloOutlet: UILabel!
    @IBOutlet weak var SwitchOutlet: UISwitch!
    @IBOutlet weak var MessageOutlet: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.SwitchOutlet.enabled = false   // disable Switch!
        HulloOutlet.text = "Loading"
        
        self.SparkLogin()
        
        HulloOutlet.text = "Linking Wooly Heater"
    }
    
    func SparkLogin()   //\\//\\//\\//\\//\\//\\// Login //\\//\\//\\//\//\\//\\//
    {
        
        dispatch_async(dispatch_get_global_queue(priority, 0)) { // log in
            dispatch_group_enter(self.loginGroup);
            dispatch_group_enter(self.deviceGroup);
            
            if SparkCloud.sharedInstance().isAuthenticated {
                print("logging out of old session")
                SparkCloud.sharedInstance().logout()
            }
            
            SparkCloud.sharedInstance().loginWithUser(self.username, password: self.password, completion: { (error : NSError?) in
                if let _ = error {
                    print("Wrong credentials or no internet connectivity, please try again")
                } else {
                    print("Logged in with user " + self.username) // or with injected token
                }
                dispatch_group_leave(self.loginGroup)
            })
        }
        
        connect()
        getState()
        events()

    
    } // END SparkLogin()
    
    func logout() {
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            dispatch_group_enter(self.loginGroup);
            dispatch_group_enter(self.deviceGroup);
            
            if SparkCloud.sharedInstance().isAuthenticated {
                print("logging out of old session")
                SparkCloud.sharedInstance().logout()
            }
        }
    }
    
    func connect() {
        dispatch_async(dispatch_get_global_queue(self.priority, 0)) { // get Photon
            dispatch_group_wait(self.loginGroup, DISPATCH_TIME_FOREVER)
            SparkCloud.sharedInstance().getDevices { (sparkDevices:[AnyObject]?, error:NSError?) -> Void in
                if let _=error {
                    print("Check your internet connectivity")
                } else {
                    if let devices = sparkDevices as? [SparkDevice] {
                        for device in devices {
                            if device.name == self.deviceName {
                                print("found " + self.deviceName)
                                self.myPhoton = device
                                dispatch_group_leave(self.deviceGroup)
                            }
                        }
                        if (self.myPhoton == nil) {
                            print("device with name " + self.deviceName+" not found in account")
                        }
                    }
                }
            }
        }
    }
    
    func getState() {
        dispatch_async(dispatch_get_global_queue(self.priority, 0)) { // logging in
            dispatch_group_wait(self.deviceGroup, DISPATCH_TIME_FOREVER) // 5
            dispatch_group_enter(self.deviceGroup)
            
            let functionName = "heatIt"
            let funcArgs = [""]
            self.myPhoton!.callFunction(functionName, withArguments: funcArgs) {
                (resultCode : NSNumber?, error : NSError?) -> Void in
                if (error == nil) {
                    if (resultCode! == 1) {
                        self.HulloOutlet.text = "on"
                        self.SwitchOutlet.on = true
                    } else {
                        self.HulloOutlet.text = "off"
                        self.SwitchOutlet.on = false
                    }
                    
                    print(" Got initial Heater State : enable SwitchOutlet")
                    self.SwitchOutlet.enabled = true    // switch up & running
                    
                    dispatch_group_leave(self.deviceGroup)
                    
                } else {
                    print("Failed to call function " + functionName + " on device " + self.deviceName)
                    // enable button for potential retry
                    self.SwitchOutlet.enabled = true   // enable Switch!
                    self.HulloOutlet.text = "Fuck Up! Try again"
                }
            }
        }
    }
    
    func events() {
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            dispatch_group_wait(self.deviceGroup, DISPATCH_TIME_FOREVER)
            dispatch_group_enter(self.deviceGroup);
            
            self.myEventId = self.myPhoton!.subscribeToEventsWithPrefix("Wooly", handler: { (event: SparkEvent?, error:NSError?) -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    
                    print(">>> ", event!.event)
                    self.MessageOutlet.text = "\(event!.event) : \((event!.data)!)"
                    
                    let retVal : String = (event!.data)!
                    if retVal == "ON"  {
                        self.HulloOutlet.text = "on"
                        self.SwitchOutlet.enabled = true
                        self.SwitchOutlet.on = true
                    } else if retVal == "OFF"  {
                        self.HulloOutlet.text = "off"
                        self.SwitchOutlet.enabled = true
                        self.SwitchOutlet.on = false
                    }
                })
            });
            
        } // END Listen for Event
    }

    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func SwitchAction(sender: AnyObject) {
        
        var funcArgs = [""]
        if SwitchOutlet.on {
            funcArgs = ["on"]
            HulloOutlet.text = "Switching ON"
            
        } else {
            funcArgs = ["off"]
            HulloOutlet.text = "Switching OFF"
        }
        
        SwitchOutlet.enabled = false    //  ******  switch disabled   ******
        
        let functionName = "heatIt"
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
                        
            self.myPhoton!.callFunction(functionName, withArguments: funcArgs) {
                (resultCode : NSNumber?, error : NSError?) -> Void in
                
                if (error == nil) {
                    print("SwitchAction call function " + functionName + " on device " + self.deviceName + " result: ", resultCode! )
                } else {
                    print("Failed to call function " + functionName  + " error : " + error!.localizedDescription)
                }
            }
        }
    }  // END  SwitchAction()
    
    
    @IBAction func XAction(sender: AnyObject) {
        
        self.getState()
        
        self.MessageOutlet.text = "press on"
        // self.SparkLogin()
    }

    
    /*
    @IBAction func ConnectAction(sender: AnyObject) {
       //// ConnectOutlet.title = "ConnectOutlet "
        print ("ConnectAction ")
    }
    */

} // END class ViewController

