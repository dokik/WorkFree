/*! @file OIDFieldMapping.h
    @brief AppAuth iOS SDK
    @copyright
        Copyright 2015 Google Inc. All Rights Reserved.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! @typedef OIDFieldMappingConversionFunction
    @brief Represents a function which transforms incoming source values into instance variable
        values.
 */
typedef _Nullable id(^OIDFieldMappingConversionFunction)(NSObject *_Nullable value);

/*! @class OIDFieldMapping
    @brief Describes the mapping of a key/value pair to an iVar with an optional conversion
        function.
 */
@interface OIDFieldMapping : NSObject

/*! @property name
    @brief The name of the instance variable the field should be mapped to.
 */
@property(nonatomic, readonly) NSString *name;

/*! @property expectedType
    @brief The type of the instance variable.
 */
@property(nonatomic, readonly) Class expectedType;

/*! @property conversion
    @brief An optional conversion function which specifies a transform from the incoming data to the
        instance variable value.
 */
@property(nonatomic, readonly, nullable) OIDFieldMappingConversionFunction conversion;

/*! @fn init
    @internal
    @brief Unavailable. Please use initWithName:type:conversion:.
 */
- (nullable instancetype)init NS_UNAVAILABLE;

/*! @fn initWithName:type:conversion:
    @brief The designated initializer.
    @param name The name of the instance variable the field should be mapped to.
    @param type The type of the instance variable.
    @param conversion An optional conversion function which specifies a transform from the incoming
        data to the instance variable value. Used during the process performed by
        @c OIDFieldMapping.remainingParametersWithMap:parameters:instance: but not during
        encoding/decoding, since the encoded and decoded values should already be of the type
        specified by the @c type parameter.
 */
- (nullable instancetype)initWithName:(NSString *)name
                                 type:(Class)type
                           conversion:(nullable OIDFieldMappingConversionFunction)conversion
    NS_DESIGNATED_INITIALIZER;

/*! @fn initWithName:type:
    @brief A convenience initializer.
    @param name The name of the instance variable the field should be mapped to.
    @param type The type of the instance variable.
 */
- (nullable instancetype)initWithName:(NSString *)name
                                 type:(Class)type;

/*! @fn remainingParametersWithMap:parameters:instance:
    @brief Performs a mapping of key/value pairs in an incoming parameters dictionary to instance
        variables, returning a dictionary of parameter key/values which didn't map to instance
        variables.
    @param map A mapping of incoming keys to instance variables.
    @param parameters Incoming key value pairs to map to an instance's variables.
    @param instance The instance whose variables should be set based on the mapping.
    @return A dictionary of parameter key/values which didn't map to instance variables.
 */
+ (NSDictionary<NSString *, NSObject<NSCopying> *> *)remainingParametersWithMap:
    (NSDictionary<NSString *, OIDFieldMapping *> *)map
    parameters:(NSDictionary<NSString *, NSObject<NSCopying> *> *)parameters
      instance:(id)instance;

/*! @fn encodeWithCoder:map:instance:
    @brief This helper method for @c NSCoding implementations performs a serialization of fields
        defined in a field mapping.
    @param aCoder An @c NSCoder instance to serialize instance variable values to.
    @param map A mapping of keys to instance variables.
    @param instance The instance whose variables should be serialized based on the mapping.
 */
+ (void)encodeWithCoder:(NSCoder *)aCoder
                    map:(NSDictionary<NSString *, OIDFieldMapping *> *)map
               instance:(id)instance;

/*! @fn decodeWithCoder:map:instance:
    @brief This helper method for @c NSCoding implementations performs a deserialization of
        fields defined in a field mapping.
    @param aCoder An @c NSCoder instance from which to deserialize instance variable values from.
    @param map A mapping of keys to instance variables.
    @param instance The instance whose variables should be deserialized based on the mapping.
 */
+ (void)decodeWithCoder:(NSCoder *)aCoder
                    map:(NSDictionary<NSString *, OIDFieldMapping *> *)map
               instance:(id)instance;

/*! @fn JSONTypes
    @brief Returns an @c NSSet of classes suitable for deserializing JSON content in an
        @c NSSecureCoding context.
 */
+ (NSSet *)JSONTypes;

/*! @fn URLConversion
    @brief Returns a function for converting an @c NSString to an @c NSURL.
 */
+ (OIDFieldMappingConversionFunction)URLConversion;

@end

NS_ASSUME_NONNULL_END
