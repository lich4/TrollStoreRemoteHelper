
#import <Foundation/Foundation.h>

static void dylibMain();
class Entry {
public:
    Entry() {
        dylibMain();
    }
} entry;

void dylibMain() {
    @autoreleasepool {
        NSLog(@"TrollStoreTweakLoader init");
    }
}


