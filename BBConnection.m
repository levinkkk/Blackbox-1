//
//  BBConnection.m
//  Blackbox
//
//  Created by Matt Patenaude on 1/18/10.
//  Copyright 2010 Matt Patenaude.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "BBConnection.h"
#import "BBServer.h"
#import "BBResponder.h"
#import "BBRequest.h"
#import "BBDataResponse.h"
#import "HTTPAsyncFileResponse.h"


@implementation BBConnection

#pragma mark Deallocator
- (void)dealloc
{
	[associatedIdentifier release];
	[asyncRequest release];
	[super dealloc];
}

#pragma mark Properties
- (NSString *)associatedIdentifier
{
	return associatedIdentifier;
}
- (void)setAssociatedIdentifier:(NSString *)theIdentifier
{
	if (associatedIdentifier)
	{
		[associatedIdentifier release];
		associatedIdentifier = nil;
	}
	associatedIdentifier = [theIdentifier copy];
}

#pragma mark Response methods
- (NSObject<HTTPResponse> *)responseForRequest:(BBRequest *)theRequest
{
	NSObject<HTTPResponse> *response = nil;
	if ([theRequest responseFilePath] != nil)
		response = [[HTTPAsyncFileResponse alloc] initWithFilePath:[theRequest responseFilePath] forConnection:self runLoopModes:[asyncSocket runLoopModes]];
	else
		response = [[BBDataResponse alloc] initWithRequest:theRequest];
	
	return [response autorelease];
}
- (void)sendAsynchronousResponse
{
	[super replyToHTTPRequest];
}

#pragma mark Overridden methods
- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
	if ([method isEqualToString:@"POST"])
		return YES;
	return [super supportsMethod:method atPath:path];
}
- (void)replyToHTTPRequest
{
	NSURL *requestURL = (NSURL *)CFHTTPMessageCopyRequestURL(request);
	NSString *path = [[requestURL path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
	BBResponseHandler h = [(BBServer *)server handlerForPath:path];
	if (h)
	{
		[super replyToHTTPRequest];
		return;
	}
#endif
	
	NSObject<BBResponder> *theResponder = [(BBServer *)server responderForPath:path];
	[requestURL release];
	
	if ([theResponder respondsToSelector:@selector(repliesAsynchronously)] && [theResponder repliesAsynchronously])
	{
		if (asyncRequest)
		{
			[asyncRequest release];
			asyncRequest = nil;
		}
		
		asyncRequest = [[BBRequest alloc] initWithServer:(BBServer *)server connection:self message:request asynchronous:YES];
		[theResponder handleRequest:asyncRequest];
	}
	else
		[super replyToHTTPRequest];
}
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	NSURL *requestURL = (NSURL *)CFHTTPMessageCopyRequestURL(request);
	NSString *rPath = [[requestURL path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	BBRequest *theRequest = nil;
	
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
	BBResponseHandler h = [(BBServer *)server handlerForPath:rPath];
	if (h)
	{
		theRequest = [[BBRequest alloc] initWithServer:(BBServer *)server connection:self message:request asynchronous:NO];
		h(theRequest);
	}
	else
	{
#endif
	
	NSObject<BBResponder> *theResponder = [(BBServer *)server responderForPath:rPath];
	[requestURL release];
	
	if ([theResponder respondsToSelector:@selector(repliesAsynchronously)] && [theResponder repliesAsynchronously] && asyncRequest != nil)
	{
		theRequest = [asyncRequest retain];
		
		if (asyncRequest)
		{
			[asyncRequest release];
			asyncRequest = nil;
		}
	}
	else
	{
		theRequest = [[BBRequest alloc] initWithServer:(BBServer *)server connection:self message:request asynchronous:NO];
		[theResponder handleRequest:theRequest];
	}
		
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
	}
#endif
		
	NSObject<HTTPResponse> *theResponse = [self responseForRequest:theRequest];
	[theRequest release];
	
	return theResponse;
}
- (void)processDataChunk:(NSData *)postDataChunk
{
	BOOL result = CFHTTPMessageAppendBytes(request, [postDataChunk bytes], [postDataChunk length]);
	
	if (!result)
		NSLog(@"Couldn't append bytes!");
}

@end
