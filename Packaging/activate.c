#include <Carbon/Carbon.h>
#include <stdio.h>
#include <string.h>
int main(int argc,char **argv) {
    if(argc!=2) return 2;
    CFURLRef url=CFURLCreateFromFileSystemRepresentation(NULL,(const UInt8*)argv[1],strlen(argv[1]),true);
    OSStatus registered=TISRegisterInputSource(url);
    CFRelease(url);
    printf("Register: %d\n",(int)registered);
    CFStringRef key=kTISPropertyInputSourceID, id=CFSTR("org.songngu.inputmethod.Telex.vi");
    CFDictionaryRef query=CFDictionaryCreate(NULL,(const void**)&key,(const void**)&id,1,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    CFArrayRef list=TISCreateInputSourceList(query,true);
    CFRelease(query);
    if(!list || !CFArrayGetCount(list)) { puts("SongNgu is not visible in this login session.");return 3; }
    TISInputSourceRef src=(TISInputSourceRef)CFArrayGetValueAtIndex(list,0);
    OSStatus enable=TISEnableInputSource(src);
    printf("Enable: %d\n",(int)enable);
    OSStatus select=TISSelectInputSource(src);
    printf("Select: %d\n",(int)select);
    TISInputSourceRef current=TISCopyCurrentKeyboardInputSource();
    CFStringRef active=current?TISGetInputSourceProperty(current,kTISPropertyInputSourceID):NULL;
    int ok=active && CFEqual(active,id);
    puts(ok?"SongNgu is active.":"SongNgu selection has not been verified.");
    if(current) CFRelease(current);
    CFRelease(list);
    return ok?0:4;
}
