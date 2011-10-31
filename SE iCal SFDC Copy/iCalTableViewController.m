//
//  iCalTableViewController.m
//  SE Mac Calendar Sync
//
//  Created by David Van Puyvelde on 25/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "iCalTableViewController.h"
#import <CalendarStore/CalendarStore.h>
#import "zkSforce.h"
#import "zkSObject.h"
#import "zkSforceClient.h"
#import "zkLoginResult.h"
#import "Utils.h"

@implementation iCalTableViewController

@synthesize list, client, selectedrows, selectall, parentwindow;


-(id) init {
    self = [super init];
    if (self != nil) {
        //set the datepickers default values
        
    }
    return self;
}

-(void)awakeFromNib {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *savedusername = [prefs stringForKey:@"username"];
    if(savedusername != nil) {
        [loginUsername setTitle:savedusername];
    }

}

-(void)loggedIn {
    [startDatePicker setDateValue:[Utils startOfWeek]];
    [endDatePicker setDateValue:[Utils endOfWeek]];
    [self setSelectedrows:[[NSMutableSet alloc] init]];
    [self setSelectall:0];
    [self getCalEvents:nil]; //get the iCal events
}

-(void)dealloc {
    [client release];
    [list release];
    [selectedrows release];
    [super dealloc];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [list count];
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    CalEvent *ev = [list objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];
    if([identifier isEqualToString:@"selectbox"]) {
        if([selectedrows containsObject:ev]) {
            return [NSNumber numberWithInt:NSOnState];
        }
        else {
            return [NSNumber numberWithInt:NSOffState];
        }
    }
    return [ev valueForKey:identifier];
}





-(IBAction)getCalEvents:(id)sender {
    // Create a predicate to fetch all events
    NSDate *startDate = [startDatePicker dateValue];
    NSDate *endDate = [endDatePicker dateValue];
    
    NSPredicate *eventsForThisYear = [CalCalendarStore eventPredicateWithStartDate:startDate endDate:endDate
                                                                         calendars:[[CalCalendarStore defaultCalendarStore] calendars]];
    
    // Fetch all events
    [self setList:[[CalCalendarStore defaultCalendarStore] eventsWithPredicate:eventsForThisYear]];

    
    [tableView reloadData];
}


- (IBAction) tableViewSelected:(id)sender {
    CalEvent *ev = [list objectAtIndex:[sender clickedRow]];    
    [calEventNotes setString:[ev notes]];
    [calEventNotes setEditable:FALSE];
}

- (IBAction)saveToSalesforce:(id)sender {

    NSMutableArray *saveobjects = [[NSMutableArray alloc] init ];
    
    for(CalEvent *ev in selectedrows) {
        
        //create the ZKSobject and set the field values
        ZKSObject *saveObj = [[ZKSObject alloc] initWithType:@"Event"];
        [saveObj setFieldValue:[ev title] field:@"Subject"];
        [saveObj setFieldValue:[ev location] field:@"Location"];
        [saveObj setFieldValue:[ev description] field:@"Description"];
        [saveObj setFieldDateTimeValue:[ev startDate] field:@"ActivityDateTime"];
        
        //calculate meeting length
        // Get the system calendar
        NSCalendar *sysCalendar = [NSCalendar currentCalendar];
        NSDateComponents *breakdowninfo = [sysCalendar components:NSMinuteCalendarUnit fromDate:[ev startDate] toDate:[ev endDate] options:0];
        
        NSInteger minutes = [breakdowninfo minute];
        NSString *duration = [NSString stringWithFormat:@"%d", minutes];
        [saveObj setFieldValue:duration field:@"DurationInMinutes"];
        [saveobjects addObject:saveObj];
        [saveObj release];
    }
    
    NSArray *results = [client create:[NSArray arrayWithObject:saveobjects]];
    
    //see if there are any errors
    NSString *message = [[NSString alloc] init];
    NSMutableString *details = [[NSMutableString alloc] init];
    BOOL success = true;
    for(ZKSaveResult *sr in results) {
        if([sr success]) {

        }
        else {
            success = false;
            [details appendString:[sr message]];
            NSLog(@"Error saving activity : %@", [sr message]);
            
        }
    }
    
    if(success) {
        message = @"Activities saved to Salesforce";
    }
    else {
        message = @"There where errors";
    }
    
    [self alert:message details:details];
         
    [message release];
    [details release];
    [saveobjects release];
}


// previous and next week buttons
- (IBAction)previousButtonClick:(id)sender {
    [startDatePicker setDateValue:[Utils substractOneWeek:[startDatePicker dateValue]]];
    [endDatePicker setDateValue:[Utils substractOneWeek:[endDatePicker dateValue]]];
    [selectedrows removeAllObjects];
    [selectAllCheckbox setState:0];
    [self getCalEvents:nil];
}

- (IBAction)nextButtonClick:(id)sender {
    [startDatePicker setDateValue:[Utils addOneWeek:[startDatePicker dateValue]]];
    [endDatePicker setDateValue:[Utils addOneWeek:[endDatePicker dateValue]]];
    [selectedrows removeAllObjects];
    [selectAllCheckbox setState:0];
    [self getCalEvents:nil];    
}


//when the select box is clicked
- (IBAction)selectBoxClicked:(id)sender {
    CalEvent *ev = [list objectAtIndex:[tableView selectedRow]];
    if([selectedrows containsObject:ev]) {
        [selectedrows removeObject:ev];
    }
    else {
        [selectedrows addObject:ev];
    }
}


//when the 'select all' button is clicked
- (IBAction)selectAllClicked:(id)sender {
    NSLog(@"State : %ld", [selectAllCheckbox state]);
    if([selectAllCheckbox state] == 1) {
        [selectedrows addObjectsFromArray:[self list]];
    }
    else if([selectAllCheckbox state] == 0) {
        [selectedrows removeAllObjects];
    }
    [tableView reloadData];
}


//login button clicked
- (IBAction)loginButtonClicked:(id)sender {
    client = [[ZKSforceClient alloc] init];
    NSString *un = [loginUsername title];
    NSString *pw = [loginPassword title];
    //ZKLoginResult *lr = [client login:@"dvp@sdo1111.demo" password:@"sfdc1234"];
    ZKLoginResult *lr = [client login:un password:pw];
    NSLog(@"Logged in as : %@", [[lr userInfo] userName]);
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setValue:[[lr userInfo] userName] forKey:@"username"];
    
    //NSLog(@"Login button clicked : %@", [loginUsername title]);
    [self loggedIn];
    [loginPanel close];
}


//bring up an alert window
-(void)alert:(NSString *) message details:(NSMutableString *) details {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:message];
    [alert setInformativeText:details];
    [alert setAlertStyle:NSInformationalAlertStyle];
    
    [alert beginSheetModalForWindow:[self parentwindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    
}

//alert return callback
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    NSLog(@"Alert returned");
}






@end
