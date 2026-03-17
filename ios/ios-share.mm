// SPDX-License-Identifier: GPL-2.0
//
// this code was inspired by the discussions in
// https://forum.qt.io/topic/88297/native-objective-c-calls-from-cpp-qt-ios-email-call

// this include file only has the C++/Qt headers that can be used from C++
#include "ios-share.h"

// these are the required ObjC++ headers
#import <Foundation/Foundation.h>
#import <Foundation/NSString.h>
#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// declare an ObjC++ class that will interact with the mail controller
// that second member that is called when the mail app is finished is critical for this to work
@interface IosShareObject : UIViewController  <MFMailComposeViewControllerDelegate, UIDocumentPickerDelegate>
{
}

@property(nonatomic, assign) IosShare *share;

- (void)shareViaEmail:(const QString &) subject :(const QString &) recipient :(const QString &) body :(const QString &) firstPath :(const QString &) secondPath;
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(nullable NSError *)error;
- (void)shareViaSharesheet:(const QString &) filePath;
- (void)showFilePicker;
- (UIViewController *)topMostViewController;
@end

@implementation IosShareObject
// first, inside the implementation of the ObjC++ class, implement the Qt class
IosShare::IosShare() : self(NULL) {
	// call init to ensure that the ObjC++ object is instantiated, which in return
	// apparently sets up the Controller
	self = [ [IosShareObject alloc] init];
	((IosShareObject *)self).share = this;
}

IosShare::~IosShare() {
//  this call below apparently caused a crash at exit.
//  since at exit I really don't care much about a memory leak, this should be fine.
//	[(id)self dealloc];
}

// simplified method that fills subject, recipient, and body for support emails
void IosShare::supportEmail(const QString &firstPath, const QString &secondPath) {
	QString subject("Subsurface-mobile support request");
	QString recipient("in-app-support@subsurface-divelog.org");
	QString body("Please describe your issue here and keep the attached logs.\n\n\n\n");
	shareViaEmail(subject, recipient, body, firstPath, secondPath);
}

void IosShare::shareViaEmail(const QString &subject, const QString &recipient, const QString &body, const QString &firstPath, const QString &secondPath) {
	// ObjC++ syntax to call the shareViaEmail method of that class - so this is
	// where we transition from Qt/C++ code to ObjC++ code that can interact
	// directly with iOS
	[(id)self shareViaEmail:subject:recipient:body:firstPath:secondPath];
}

void IosShare::shareWithSharesheet(const QString &filePath)
{
	[(id)self shareViaSharesheet:filePath];
}

void IosShare::showFilePicker()
{
	[(id)self showFilePicker];
}

// the rest is the ObjC++ implementation
- (instancetype)init {
	// this is just boiler plate that I really don't understand
	// it appears to make sure that the ViewController infrastructure is initialized?
	return super.init;
}

- (void)shareViaEmail:(const QString &) subjectQS :(const QString &) recipientQS :(const QString &) bodyQS :(const QString &) firstPathQS :(const QString &) secondPathQS {
	// since we are mixing Qt and ObjC++ data structures, let's allocate copies
	// of our Qt strings and convert recipients into an array
	NSString *firstPath = [[NSString alloc] initWithUTF8String:firstPathQS.toUtf8().data()];
	NSString *secondPath = [[NSString alloc] initWithUTF8String:secondPathQS.toUtf8().data()];
	NSString *subject = [[NSString alloc] initWithUTF8String:subjectQS.toUtf8().data()];
	NSString *recipient = [[NSString alloc] initWithUTF8String:recipientQS.toUtf8().data()];
	NSString *body = [[NSString alloc] initWithUTF8String:bodyQS.toUtf8().data()];
	NSArray *recipents = [NSArray arrayWithObject:recipient];
	// create the mail controller and connect it with the object
	MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
	mc.mailComposeDelegate = self;
	[mc setSubject:subject];
	[mc setMessageBody:body isHTML:NO];
	[mc setToRecipients:recipents];
	// set up up to two attachments - only if we have a path and the file isn't empty (iOS throws up if you have an empty attachment)
	if (!firstPathQS.isEmpty()) {
		NSData *myData = [NSData dataWithContentsOfFile: firstPath];
		if (myData != nil)
			[mc addAttachmentData:myData mimeType:@"text/plain" fileName:[firstPath lastPathComponent]];
	}
	if (!secondPathQS.isEmpty()) {
		//NSString *path = [[NSBundle mainBundle] pathForResource:@"log2" ofType:@"txt"];
		NSData *myData = [NSData dataWithContentsOfFile: secondPath];
		if (myData != nil)
			[mc addAttachmentData:myData mimeType:@"text/plain" fileName:[secondPath lastPathComponent]];
	}
	// more black magic; get a view controller that is connected to our application window
	UIViewController * topController = [UIApplication sharedApplication].keyWindow.rootViewController;
	while (topController.presentedViewController){
		topController = topController.presentedViewController;
	}
	// finally, show the controller - the code returns right away, which is why we need the 'didFinishWithResult' method below
	[topController presentViewController:mc animated:YES completion:NULL];
}

- (void)shareViaSharesheet:(const QString &)filePathQS {
	NSString *path = [[NSString alloc] initWithUTF8String:(filePathQS.toUtf8().data())];

	if (path.length == 0) return;
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;

	void (^present)(void) = ^{
	  UIViewController *vc = [self topMostViewController];
	  if (!vc) return;

	  NSURL *fileURL = [NSURL fileURLWithPath:path isDirectory:NO];
	  UIActivityViewController *avc =
		  [[UIActivityViewController alloc] initWithActivityItems:@[fileURL]
						    applicationActivities:nil];

	  UIPopoverPresentationController *pop = avc.popoverPresentationController;
	  if (pop) {
		  pop.sourceView = vc.view;
		  CGRect b = vc.view.bounds;
		  pop.sourceRect = CGRectMake(CGRectGetMidX(b), CGRectGetMidY(b), 1, 1);
		  pop.permittedArrowDirections = 0;
	  }

	  [vc presentViewController:avc animated:YES completion:nil];
	};

	if ([NSThread isMainThread]) { present(); }
	else { dispatch_async(dispatch_get_main_queue(), present); }
}

- (void)showFilePicker {

	UIViewController *top = [self topMostViewController];
	if (!top) {
		return;
	};

	UIDocumentPickerViewController *picker;

	picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier: @"public.xml"], UTTypeData]];
	picker.allowsMultipleSelection = false;
	picker.delegate = self;
	picker.modalPresentationStyle = UIModalPresentationFormSheet;
	[top presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	if (urls.count != 1) return;
	NSURL *url = urls.firstObject;

	if (![url startAccessingSecurityScopedResource]) return;

	NSError *outerError = nil;
	NSFileCoordinator *coord = [[NSFileCoordinator alloc] init];

	__block NSURL *localURL = nil;
	__block NSError *copyError = nil;

	[coord coordinateReadingItemAtURL:url options:0 error:&outerError byAccessor:^(NSURL *newURL) {
		NSNumber *isUbiquitous = nil;
		[newURL getResourceValue:&isUbiquitous forKey:NSURLIsUbiquitousItemKey error:nil];
		if (isUbiquitous.boolValue) {
			NSNumber *isDownloaded = nil;
			[newURL getResourceValue:&isDownloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:nil];
			if (!isDownloaded.boolValue) {
				[[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:newURL error:nil];
				for (int i = 0; i < 100 && !isDownloaded.boolValue; i++) {
					[NSThread sleepForTimeInterval:0.05];
					[newURL getResourceValue:&isDownloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:nil];
				}
			}
		}

		NSString *destinationName = newURL.lastPathComponent ?: @"picked";
		NSURL *destinationUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:destinationName]];
		NSFileManager *fileManager = NSFileManager.defaultManager;
		[fileManager removeItemAtURL:destinationUrl error:nil];
		if (![fileManager copyItemAtURL:newURL toURL:destinationUrl error:&copyError]) {
			return;
		}

		localURL = destinationUrl;
	}];

	[url stopAccessingSecurityScopedResource];

	if (outerError) {
		NSLog(@"Coordinator err: %@", outerError);
		return;
	}
	if (copyError) {
		NSLog(@"Copy error: %@", copyError);
		return;
	}
	if (!localURL) {
		NSLog(@"No local URL");
		return;
	}

	emit self.share->fileSelected(QString(localURL.absoluteString.UTF8String));
}

- (UIViewController *)topMostViewController {
	UIWindow *key = nil;
	if (@available(iOS 13.0, *)) {
		for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
			if (s.activationState != UISceneActivationStateForegroundActive) continue;
			if (![s isKindOfClass:UIWindowScene.class]) continue;
			for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { key = w; break; }
			if (key) break;
		}
	}
	if (!key) key = UIApplication.sharedApplication.keyWindow;
	UIViewController *vc = key.rootViewController;
	while (YES) {
		if ([vc isKindOfClass:UINavigationController.class]) vc = ((UINavigationController *)vc).visibleViewController ?: vc;
		else if ([vc isKindOfClass:UITabBarController.class]) vc = ((UITabBarController *)vc).selectedViewController ?: vc;
		else if (vc.presentedViewController) vc = vc.presentedViewController;
		else break;
	}
	return vc;
}

// I would have kinda liked to inform the caller that sending mail failed, but I can't figure
// out how to get that information back to the Qt code calling us. Oh well. At least we log the results.
// But the critically important part is that we dismiss the view controller.
- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(nullable NSError *)error {
	switch (result) {
	case MFMailComposeResultCancelled:
		NSLog(@"Mail cancelled");
		break;
	case MFMailComposeResultSaved:
		NSLog(@"Mail saved");break;
	case MFMailComposeResultSent:
		NSLog(@"Mail sent");break;
	case MFMailComposeResultFailed:
		NSLog(@"Mail sent failure: %@", [error localizedDescription]);
		break;
	default:
		break;
	}
	[controller dismissViewControllerAnimated:YES completion:NULL];
}
@end
