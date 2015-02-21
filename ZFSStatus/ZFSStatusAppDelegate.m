//
//  ZFSStatusAppDelegate.m
//  ZFSStatus
//
//  Created by Alex Wasserman on 7/8/14.
//  Copyright (c) 2014 Alex Wasserman. All rights reserved.
//

#import "ZFSStatusAppDelegate.h"

@interface ZFSStatusAppDelegate ()

@end

@implementation ZFSStatusAppDelegate

#define defaultValue @"ZPool"
#define defaultInterval @"300"
#define poolNameKey @"poolName"
#define intervalKey @"refreshInterval"

NSString *Status = @"Sampling";

- (void)awakeFromNib
{
    
    [self runTimer];
    
}

- (void)runTimer
{
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{intervalKey: defaultInterval}];
    NSTimeInterval interval = [[NSUserDefaults standardUserDefaults] doubleForKey:intervalKey];

    [updateTimer invalidate];
    
    updateTimer = [NSTimer
                   scheduledTimerWithTimeInterval:(interval)
                   target:self
                   selector:@selector(getZfsStatus:)
                   userInfo:nil
                   repeats:YES];
}


- (void)savePrefs:(id)sender {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *poolName;
    NSString *interval;

    
    poolName = [poolNameField stringValue];
    interval = [refreshIntervalField stringValue];
    
    [defaults setObject:interval forKey:intervalKey];
    [defaults setObject:poolName forKey:poolNameKey];
    
    [updateTimer invalidate];
    [self runTimer];
    
    NSLog(@"Saving prefs");
    
}

- (void)dealloc
{
    [updateTimer invalidate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *poolName = [defaults stringForKey:poolNameKey];
    if (poolName == nil) poolName = defaultValue;
    [poolNameField setStringValue:poolName];
    
    NSString *interval = [defaults stringForKey:intervalKey];
    if (poolName == nil) poolName = defaultValue;
    [refreshIntervalField setStringValue:interval];
    
    [self setupStatusItem];
    [self getZfsStatus:nil];

}

- (void)setupStatusItem
{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    statusItem.title = [NSString stringWithString:(Status) ];
    statusItem.image = [NSImage imageNamed:@"icon"];
    statusItem.highlightMode = YES;
    
    [self setupMenu];
}

- (void)setupMenu
{
    zfsMenu = [[NSMenu alloc] initWithTitle:@""];
    [zfsMenu setDelegate:self];
    [zfsMenu addItem:[NSMenuItem separatorItem]];
    [zfsMenu addItemWithTitle:@"Start/Stop Scrub" action:@selector(scrub:) keyEquivalent:@""];
    [zfsMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *prefsMenuItem = [zfsMenu addItemWithTitle:@"Preferences" action:@selector(makeKeyAndOrderFront:) keyEquivalent:@""];
    [zfsMenu addItemWithTitle:@"About ZFSStatus" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [zfsMenu addItemWithTitle:@"Quit ZFSStatus" action:@selector(terminate:) keyEquivalent:@""];
    
    [prefsMenuItem setTarget:prefsPanel];
    
    statusItem.menu = zfsMenu;
    
}

- (void)scrub:(id)sender
{
        
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{poolNameKey: defaultValue}];
    NSString *PoolName = [[NSUserDefaults standardUserDefaults] stringForKey:poolNameKey];
    
    NSString *scrubCommand = [NSString stringWithFormat:@"/usr/sbin/zpool status %@ | grep 'scan: scrub in progress'", PoolName ];
    NSString *startScrubCommand = [NSString stringWithFormat:@"/usr/sbin/zpool scrub %@ ", PoolName ];
    NSString *stopScrubCommand = [NSString stringWithFormat:@"/usr/sbin/zpool scrub -s %@ ", PoolName ];
    
    NSString *scrubStatus = runCommand(scrubCommand);
    
    if ( [scrubStatus length] == 0 )
        runCommand(startScrubCommand);
    else if(scrubStatus != NULL)
        runCommand(stopScrubCommand);
    
    NSLog(@"Updating menu bar status");

}

- (void)getZfsStatus:(id)sender
{
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{poolNameKey: defaultValue}];
    NSString *PoolName = [[NSUserDefaults standardUserDefaults] stringForKey:poolNameKey];
    
    statusItem.title = [NSString stringWithString:(Status)];
    
    NSString *completeStatusCommand = [NSString stringWithFormat:@"/usr/sbin/zpool status %@ | grep state: | awk '{ printf \"%%s\", $2 }'", PoolName ];
    
    NSString *zfsStatus = runCommand(completeStatusCommand);
    
    if ( [zfsStatus length] == 0 )
        statusItem.title = @"No pool found";
    else if(zfsStatus != NULL)
        [statusItem setTitle:
         [NSString stringWithString:zfsStatus]];
    else
        statusItem.title = [NSString stringWithString:(Status) ];
    
    NSLog(@"Updating menu bar status");
    
}



- (void)menuNeedsUpdate:(NSMenu *)zfsMenu
{
    NSInteger i;
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{poolNameKey: defaultValue}];
    NSString *PoolName = [[NSUserDefaults standardUserDefaults] stringForKey:poolNameKey];
    
    NSString *completeDetailsCommand = [NSString stringWithFormat:@"date && /usr/sbin/zpool status %@", PoolName ];
    
    NSString *zfsStatusDetail = runCommand(completeDetailsCommand);
    
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[[NSString stringWithString:zfsStatusDetail] componentsSeparatedByString:@"\n"]];
    
    while ([[lines lastObject] isEqualToString:@""])
        [lines removeLastObject];
    
    NSFont *textFont;
    NSColor *textForeground;
    
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    //textBackground, NSBackgroundColorAttributeName,
                                    textForeground, NSForegroundColorAttributeName,
                                    textFont, NSFontAttributeName,
                                    NULL];
    
    while ([self->zfsMenu numberOfItems] > 6)
        [self->zfsMenu removeItemAtIndex:0];
    
    if ( [lines count] == 0 ) {
        NSMenuItem *zfsDetails = [[NSMenuItem alloc] initWithTitle:@"Pool not found" action:NULL keyEquivalent:@""];
        NSAttributedString *attStr = [[NSAttributedString alloc] initWithString:@"Pool not found" attributes:textAttributes];
        [zfsDetails setAttributedTitle:attStr];
        [self->zfsMenu insertItem:zfsDetails atIndex:0];
    }
    
    for (i = [lines count] - 1; i >= 0; i--) {
        NSMenuItem *zfsDetails = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
        
        NSAttributedString *attStr = [[NSAttributedString alloc] initWithString:[lines objectAtIndex:i] attributes:textAttributes];
        [zfsDetails setAttributedTitle:attStr];
        [self->zfsMenu insertItem:zfsDetails atIndex:0];
    }
    
}





NSString *runCommand(NSString *commandToRun)
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/sh"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    //NSLog(@"run command: %@",commandToRun);
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *output;
    output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    return output;
}


- (void)terminate:(id)sender
{
    [[NSApplication sharedApplication] terminate:statusItem.menu];
}


@end
