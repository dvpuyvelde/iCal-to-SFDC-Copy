//
//  iCalTableViewController.h
//  SE Mac Calendar Sync
//
//  Created by David Van Puyvelde on 25/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "zkSforceClient.h"


@interface iCalTableViewController : NSObject <NSTableViewDataSource> {
    IBOutlet NSTableView *tableView;
    IBOutlet NSTextView *calEventNotes;
    IBOutlet NSDatePicker *startDatePicker;
    IBOutlet NSDatePicker *endDatePicker;
    IBOutlet NSButtonCell *selectAllCheckbox;
    NSArray *list;
    NSMutableSet *selectedrows;
    NSMutableSet *salesforceevents;
    NSInteger selectall;
    IBOutlet NSWindow *parentwindow;
    ZKSforceClient *client;
    IBOutlet NSPanel *loginPanel;
    IBOutlet NSTextFieldCell *loginUsername;
    IBOutlet NSSecureTextFieldCell *loginPassword;
    IBOutlet NSSecureTextField *loginTextField;
}


@property (retain) NSArray *list;
@property (retain) NSMutableSet *selectedrows;
@property (retain) NSMutableSet *salesforceevents;
@property (assign) NSInteger selectall;
@property (retain) ZKSforceClient *client;
@property (retain) NSWindow *parentwindow;


//table view datasource methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;

-(void)loggedIn;

- (IBAction)getCalEvents:(id)sender;
- (IBAction)tableViewSelected:(id)sender;
- (IBAction)saveToSalesforce:(id)sender;
- (IBAction)previousButtonClick:(id)sender;
- (IBAction)nextButtonClick:(id)sender;
- (IBAction)selectBoxClicked:(id)sender;
- (IBAction)selectAllClicked:(id)sender;
- (IBAction)loginButtonClicked:(id)sender;
- (IBAction)passwordEnterKey:(id)sender;
-(void)alert:(NSString *) message details:(NSMutableString *) details;

@end
