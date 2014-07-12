//
//  ZFSStatusAppDelegate.h
//  ZFSStatus
//
//  Created by Alex Wasserman on 7/8/14.
//  Copyright (c) 2014 Alex Wasserman. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ZFSStatusAppDelegate : NSObject <NSMenuDelegate>
{
NSStatusItem *statusItem;
NSMenu *zfsMenu;
NSTimer *updateTimer;

IBOutlet NSTextField *poolNameField;
IBOutlet NSTextField *refreshIntervalField;
IBOutlet id prefsPanel;
    
}

- (IBAction)savePrefs:(id)sender;

@end
