//
//  MyLicenseVerifier.m
//  AppGrid
//
//  Created by Steven Degutis on 3/3/13.
//  Copyright (c) 2013 Steven Degutis. All rights reserved.
//

#import "MyLicenseVerifier.h"

#import "CFobLicVerifier.h"

#define MyLicenseNameDefaultsKey @"MyLicenseNameDefaultsKey"
#define MyLicenseCodeDefaultsKey @"MyLicenseCodeDefaultsKey"

#define MyInitialDateKey @"NSWindowTopLeftPositionalSetting"

//#define MY_EXPIRATION_TIME (60 * 10)
#define MY_EXPIRATION_TIME (60 * 60 * 24 * 30)

@interface MyLicenseVerifier ()

@property BOOL isNagging;

@end

@implementation MyLicenseVerifier

+ (BOOL) expired {
//    NSLog(@"%@", [self initialDate]);
//    NSLog(@"%@", [NSDate date]);
    NSDate* expires = [[self initialDate] dateByAddingTimeInterval:MY_EXPIRATION_TIME];
    NSDate* now = [NSDate date];
    return ([now compare: expires] == NSOrderedDescending);
}

+ (NSDate*) initialDate {
    NSData* data = [[NSUserDefaults standardUserDefaults] dataForKey:MyInitialDateKey];
    
    if (data == nil) {
        NSData* now = [NSKeyedArchiver archivedDataWithRootObject:[NSDate date]];
        [[NSUserDefaults standardUserDefaults] setObject:now forKey:MyInitialDateKey];
        
        return [self initialDate];
    }
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

+ (BOOL) tryRegisteringWithLicenseCode:(NSString*)licenseCode licenseName:(NSString*)licenseName {
    BOOL valid = [self verifyLicenseCode:licenseCode forLicenseName:licenseName];
    
    if (valid) {
        [[NSUserDefaults standardUserDefaults] setObject:licenseName forKey:MyLicenseNameDefaultsKey];
        [[NSUserDefaults standardUserDefaults] setObject:licenseCode forKey:MyLicenseCodeDefaultsKey];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MyLicenseVerifiedNotification
                                                            object:nil];
    }
    
    return valid;
}

+ (BOOL) verifyLicenseCode:(NSString*)licenseCode forLicenseName:(NSString*)licenseName {
    if (licenseCode == nil || licenseName == nil)
        return NO;
    
	NSString* adjustedLicenseName = [NSString stringWithFormat:@"AppGrid,%@", licenseName];
    
	NSString *publicKey =
    @"MIHxMIGpBgcqhkjOOAQBMIGdAkEApu5r"@"og+tkWTO1cMy3284VgEMmDxQmY7hJRmn"@"\n"
    @"skTFv7nRBCXva1pUhlOR/awOFyhkMBzR"@"nen1NlimxOBSiCfivQIVAOtu+QXEbzXf"@"\n"
    @"MMU1qyuhEp0o233zAkEApF6zQLuBy89f"@"J3gEP4V+N6J1hWzRv5VtQgrHpu635pkw"@"\n"
    @"eQDtkQriu3tvrw85QotzKdgZVhmDkg0U"@"o7PfZpQ+lANDAAJAFuesN0blhZdMn0SX"@"\n"
    @"EydQvrlQda7dEuI9zZo919yO/8SsSy9V"@"7PU+HklIX7elMdhjtwdUlncKgZoaZREO"@"\n"
    @"guP8lg==\n";
    
	publicKey = [CFobLicVerifier completePublicKeyPEM:publicKey];
    
	CFobLicVerifier * verifier = [[CFobLicVerifier alloc] init];
    [verifier setPublicKey:publicKey error:NULL];
    
    return [verifier verifyRegCode:licenseCode
                           forName:adjustedLicenseName
                             error:NULL];
}

+ (NSString*) licenseName {
    return [[NSUserDefaults standardUserDefaults] stringForKey:MyLicenseNameDefaultsKey];
}

+ (NSString*) licenseCode {
    return [[NSUserDefaults standardUserDefaults] stringForKey:MyLicenseCodeDefaultsKey];
}

+ (BOOL) hasValidLicense {
    return [self verifyLicenseCode:[self licenseCode] forLicenseName:[self licenseName]];
}

+ (void) sendToWebsite {
    NSString* storeUrl = @"http://giantrobotsoftware.com/appgrid/";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:storeUrl]];
}

+ (void) sendToStore {
    NSString* storeUrl = @"http://giantrobotsoftware.com/appgrid/store.html";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:storeUrl]];
}

+ (NSAlert*) alertForValidity:(BOOL)valid fromLink:(BOOL)fromLink {
    NSAlert* alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Visit Our Website"];
    
    NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    
    if (valid) {
        alert.alertStyle = NSInformationalAlertStyle;
        alert.messageText = @"AppGrid successfully registered!";
        alert.informativeText = [NSString stringWithFormat:@"Now you have the full version of %@. Congratulations!", appName];
    }
    else {
        alert.alertStyle = NSCriticalAlertStyle;
        
        if (fromLink) {
            alert.messageText = @"Invalid or Corrupted License";
            alert.informativeText = [NSString stringWithFormat:
                                     @"The auto-register link you clicked has been corrupted and can't be verified.\n\n"
                                     @"To register %@, find the license name and license code (which was emailed to you) and enter them into the License window.",
                                     appName];
        }
        else {
            alert.messageText = @"Invalid License";
            alert.informativeText =
//          @"====================================================="
            @"This license cannot be verified. Try this:\n"
            @"- Paste the entire license code (it's pretty long).\n"
            @"- Enter the exact license name you registered with.\n\n"
            @"If after doing so you're still having this error,\n"
            @"contact customer support for assistance. There is a\n"
            @"link for customer support on our website.";
        }
    }
    
    return alert;
}

+ (MyLicenseVerifier*) sharedLicenseVerifier {
    static MyLicenseVerifier* sharedLicenseVerifier;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLicenseVerifier = [[MyLicenseVerifier alloc] init];
    });
    return sharedLicenseVerifier;
}

- (void) nag {
    if (self.isNagging)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isNagging = YES;
        
        [NSApp activateIgnoringOtherApps:YES];
        NSInteger result = NSRunAlertPanel(@"AppGrid trial has expired",
                                           @"You may continue using AppGrid by purchasing a license.",
                                           @"OK",
                                           @"Purchase License...",
                                           @"Enter License");
        
        if (result == NSAlertAlternateReturn)
            [MyLicenseVerifier sendToStore];
        
        if (result == NSAlertOtherReturn)
            [[NSApp delegate] performSelector:@selector(showLicenseWindow:) withObject:self];
        
        self.isNagging = NO;
    });
    
}

@end
