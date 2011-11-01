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
#import "zkQueryResult.h"
#import "Utils.h"

@implementation iCalTableViewController

@synthesize list, client, selectedrows, selectall, parentwindow, salesforceevents;


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
    [self setSalesforceevents:[[NSMutableSet alloc] init]];
    [self setSelectall:0];
    [self getCalEvents:nil]; //get the iCal events
}

-(void)dealloc {
    [client release];
    [list release];
    [selectedrows release];
    [salesforceevents release];
    [super dealloc];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [list count];
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    CalEvent *ev = [list objectAtIndex:row];
    NSString *identifier = [tableColumn identifier];
    //for the selectbox column
    if([identifier isEqualToString:@"selectbox"]) {
        if([selectedrows containsObject:ev]) {
            return [NSNumber numberWithInt:NSOnState];
        }
        else {
            return [NSNumber numberWithInt:NSOffState];
        }
    }
    //for the image column
    if([identifier isEqualToString:@"sfdc"]) {
        //make sure to trim the title (subject) because salesforce will have trimmed them upon save (iCal doesn't)
        NSString *trimmedtitle = [[ev title] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *localkey = [[[NSString alloc] initWithFormat:@"%@_%@", [Utils formatDateTimeAsStringUTC:[ev startDate]], trimmedtitle] autorelease];
        if([salesforceevents member:localkey] == nil) {
            return nil;
        }
        else {
            return [NSImage imageNamed:@"datePicker16.gif"];
        }
    }
    //for all other columns
    return [ev valueForKey:identifier];
}



//delegate method that helps us color specific rows
- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSCell *cell = [tableColumn dataCell];
    if([cell isKindOfClass:[NSTextFieldCell class]]) {
        CalEvent *ev = [list objectAtIndex:row];
        //calculate what the 'key' for this event would be
        
        //make sure to trim the title (subject) because salesforce will have trimmed them upon save (iCal doesn't)
        NSString *trimmedtitle = [[ev title] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSString *localkey = [[[NSString alloc] initWithFormat:@"%@_%@", [Utils formatDateTimeAsStringUTC:[ev startDate]], trimmedtitle] autorelease];
        //NSLog(@"Match : %@", localkey);
        NSTextFieldCell *textcell = [tableColumn dataCell];
        //set the color to red if they're not yet in salesforce
        if([salesforceevents member:localkey] == nil) {
            [textcell setTextColor: [NSColor blackColor]];
        }
        else {
            [textcell setTextColor: [NSColor grayColor]];
        }
    }
    return cell;
}


-(IBAction)getCalEvents:(id)sender {
    //reset existing sets and arrays
    [salesforceevents removeAllObjects];
    [selectedrows removeAllObjects];
    [selectAllCheckbox setState:0];
    
    // Create a predicate to fetch all events
    NSDate *startDate = [startDatePicker dateValue];
    NSDate *endDate = [endDatePicker dateValue];
    
    NSPredicate *eventsForThisYear = [CalCalendarStore eventPredicateWithStartDate:startDate endDate:endDate
                                                                         calendars:[[CalCalendarStore defaultCalendarStore] calendars]];
    
    // Fetch all events
    [self setList:[[CalCalendarStore defaultCalendarStore] eventsWithPredicate:eventsForThisYear]];

    
    //query salesforce for Events in the same interval
    NSString *activitiesquery = [[NSString alloc ] initWithFormat:@"select Id, Subject, ActivityDateTime from Event where ActivityDate >=%@ and ActivityDate <=%@ order by StartDateTime limit 200", [Utils formatDateAsString:startDate], [Utils formatDateAsString:endDate]];
    ZKQueryResult *qr = [client query:activitiesquery];
    
    //drop them in the salesforce events set.
    for(ZKSObject *sfdcEvent in [qr records]) {
        //let's create a fake key to compare : startdatetimeinutc_subject
        //stringByTrimmingCharactersInSet:
        //[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
       // NSString *trimmedsubject = [[sfdcEvent fieldValue:@"Subject"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *eventkey = [[NSString alloc ] initWithFormat:@"%@_%@", [sfdcEvent fieldValue:@"ActivityDateTime"], [sfdcEvent fieldValue:@"Subject"]];
        NSLog(@"Added eventkey : >%@<", eventkey);
        [salesforceevents addObject:eventkey];
        [eventkey release];
    }
    
    [tableView reloadData];
    [activitiesquery release];
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
        [saveObj setFieldValue:[ev notes] field:@"Description"];
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
    
    [self getCalEvents:nil];
    
    [message release];
    [details release];
    [saveobjects release];
    
}


// previous and next week buttons
- (IBAction)previousButtonClick:(id)sender {
    [startDatePicker setDateValue:[Utils substractOneWeek:[startDatePicker dateValue]]];
    [endDatePicker setDateValue:[Utils substractOneWeek:[endDatePicker dateValue]]];
    
    [self getCalEvents:nil];
}

- (IBAction)nextButtonClick:(id)sender {
    [startDatePicker setDateValue:[Utils addOneWeek:[startDatePicker dateValue]]];
    [endDatePicker setDateValue:[Utils addOneWeek:[endDatePicker dateValue]]];

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
