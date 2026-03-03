#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "dish_placeholder" asset catalog image resource.
static NSString * const ACImageNameDishPlaceholder AC_SWIFT_PRIVATE = @"dish_placeholder";

#undef AC_SWIFT_PRIVATE
