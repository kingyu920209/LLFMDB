//
//  LLFMDB.m
//  LLFMDB
//
//  Created by 嘚嘚以嘚嘚 on 2018/5/19.
//  Copyright © 2018年 嘚嘚以嘚嘚. All rights reserved.
//

#import "LLFMDB.h"
#import <objc/runtime.h>

// 数据库中常见的几种类型
#define SQL_TEXT       @"TEXT"      //文本
#define SQL_INTEGER    @"INTEGER"   //int long integer
#define SQL_REAL       @"REAL"      //浮点
#define SQL_BLOB       @"BLOB"      //data

@interface LLFMDB ()

@property(nonatomic, strong)NSString * dbPath;       //存储地址
@property(nonatomic, strong)FMDatabaseQueue *dbQueue;//线程安全
@property(nonatomic, strong)FMDatabase *db;

@end

@implementation LLFMDB

- (FMDatabaseQueue *)dbQueue{
    if (!_dbQueue) {
        FMDatabaseQueue *fmdb = [FMDatabaseQueue databaseQueueWithPath:_dbPath];
        self.dbQueue = fmdb;
        [_db close];
        self.db = [fmdb valueForKey:@"_db"];
    }
    return _dbQueue;
}

static LLFMDB *lldb = nil;
//------------------------------单利创建-------------------------
+ (instancetype)shareDatabase{
    return [LLFMDB shareDatabase:nil];
}

+ (instancetype)shareDatabase:(NSString *)dbName
{
    return [LLFMDB shareDatabase:dbName path:nil];
}
/**
 创建数据库

 @param dbName 数据库名称
 @param dbPath 数据库存储地址
 @return 数据库
 */
+ (instancetype)shareDatabase:(NSString *)dbName path:(NSString*)dbPath
{
    static NSString * dbNamee = nil;
    dbNamee = dbName;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!lldb) {
            
            NSString * path;
            if (!dbNamee) {
                dbNamee = @"LLFMDB.sqlite";
            }
            if (!dbPath) {
                //默认存储在doc中
                path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:dbNamee];
            }else{
                path = [dbPath stringByAppendingPathComponent:dbNamee];
            }
            FMDatabase * fmdb = [FMDatabase databaseWithPath:path];
            if ([fmdb open]) {
                lldb = LLFMDB.new;
                lldb.db = fmdb;
                lldb.dbPath = path;
            }
        }
        
    });
//    if (!lldb) {
    
//        NSString * path;
//        if (!dbName) {
//            dbName = @"LLFMDB.sqlite";
//        }
//        if (!dbPath) {
//            //默认存储在doc中
//            path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:dbName];
//        }else{
//            path = [dbPath stringByAppendingPathComponent:dbName];
//        }
//        FMDatabase * fmdb = [FMDatabase databaseWithPath:path];
//        if ([fmdb open]) {
//            lldb = LLFMDB.new;
//            lldb = fmdb;
//            lldb.dbPath = path;
//        }
//    }
    if (![lldb.db open]) {
        NSLog(@"database can not open !");
        return nil;
    }
    return lldb;
}
//------------------------------非单利创建-------------------------

- (instancetype)initWithDBName:(NSString *)dbName
{
    return [self initWithDBName:dbName path:nil];
}

- (instancetype)initWithDBName:(NSString *)dbName path:(NSString *)dbPath
{
    if (!dbName) {
        dbName = @"LLFMDB.sqlite";
    }
    NSString *path;
    if (!dbPath) {
        path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:dbName];
    } else {
        path = [dbPath stringByAppendingPathComponent:dbName];
    }
    
    FMDatabase *fmdb = [FMDatabase databaseWithPath:path];
    
    if ([fmdb open]) {
        self = [self init];
        if (self) {
            self.db = fmdb;
            self.dbPath = path;
            return self;
        }
    }
    return nil;
}

- (BOOL)ll_createTable:(NSString *)tableName dicOrModel:(id)parameters
{
    return [self ll_createTable:tableName dicOrModel:parameters excludeName:nil];
}
/**
 创建表

 @param tableName 表名字
 @param parameters 储存模型
 @param nameArr 过滤key数据
 @return 是否成功
 */
- (BOOL)ll_createTable:(NSString *)tableName dicOrModel:(id)parameters excludeName:(NSArray *)nameArr
{
    NSDictionary *dic;
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
    }else{
        Class CLS;
        if ([parameters isKindOfClass:[NSString class]]) {
            if (!NSClassFromString(parameters)) {
                CLS = nil;
            }else{
                CLS = NSClassFromString(parameters);
            }
        }else if ([parameters isKindOfClass:[NSObject class]]){
            CLS = [parameters class];
        }else{
            CLS = parameters;
        }
        dic = [self modelToDictionary:CLS excludePropertyName:nameArr];
    }
    
    NSString * fieldStr = [self createTable:tableName dictionary:dic excludeName:nameArr];
    
    BOOL creatFlag;
    creatFlag = [_db executeUpdate:fieldStr];
    
    return creatFlag;

}
- (NSString *)createTable:(NSString *)tableName dictionary:(NSDictionary *)dic excludeName:(NSArray *)nameArr
{
    NSMutableString *fieldStr = [[NSMutableString alloc] initWithFormat:@"CREATE TABLE %@ (pkid  INTEGER PRIMARY KEY,", tableName];
    
    int keyCount = 0;
    for (NSString *key in dic) {
        
        keyCount++;
        if ((nameArr && [nameArr containsObject:key]) || [key isEqualToString:@"pkid"]) {
            continue;
        }
        if (keyCount == dic.count) {
            [fieldStr appendFormat:@" %@ %@)", key, dic[key]];
            break;
        }
        
        [fieldStr appendFormat:@" %@ %@,", key, dic[key]];
    }
    return fieldStr;
}
#pragma mark - *************** 增删改查
- (BOOL)ll_insertTable:(NSString *)tableName dicOrModel:(id)parameters
{
    NSArray *columnArr = [self getColumnArr:tableName db:_db];
    return [self insertTable:tableName dicOrModel:parameters columnArr:columnArr];
}

/**
 添加数据

 @param tableName 表名
 @param parameters 保存数据
 @param columnArr 表中所有字段
 @return 是否创建成功
 */
- (BOOL)insertTable:(NSString *)tableName dicOrModel:(id)parameters columnArr:(NSArray *)columnArr
{
    BOOL flag;
    NSDictionary *dic;
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
    }else {
        dic = [self getModelPropertyKeyValue:parameters tableName:tableName clomnArr:columnArr];
    }
    
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"INSERT INTO %@ (", tableName];
    NSMutableString *tempStr = [NSMutableString stringWithCapacity:0];
    NSMutableArray *argumentsArr = [NSMutableArray arrayWithCapacity:0];
    
    for (NSString *key in dic) {
        
        if (![columnArr containsObject:key] || [key isEqualToString:@"pkid"]) {
            continue;
        }
        [finalStr appendFormat:@"%@,", key];
        [tempStr appendString:@"?,"];
        
        [argumentsArr addObject:dic[key]];
    }
    
    [finalStr deleteCharactersInRange:NSMakeRange(finalStr.length-1, 1)];
    if (tempStr.length)
        [tempStr deleteCharactersInRange:NSMakeRange(tempStr.length-1, 1)];
    
    [finalStr appendFormat:@") values (%@)", tempStr];
    
    flag = [_db executeUpdate:finalStr withArgumentsInArray:argumentsArr];
    return flag;
}

/**
 删除表

 @param tableName 表名称
 @param format 删除语句
 @return 是否删除成功
 */
- (BOOL)ll_deleteTable:(NSString *)tableName whereFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    BOOL flag;
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"delete from %@  %@", tableName,where];
    flag = [_db executeUpdate:finalStr];
    
    return flag;
}

/**
 更新数据

 @param tableName 表名称
 @param parameters 更新数据
 @param format 更新语句
 @return 是否更新成功
 */
- (BOOL)ll_updateTable:(NSString *)tableName dicOrModel:(id)parameters whereFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    BOOL flag;
    NSDictionary *dic;
    NSArray *clomnArr = [self getColumnArr:tableName db:_db];
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
    }else {
        dic = [self getModelPropertyKeyValue:parameters tableName:tableName clomnArr:clomnArr];
    }
    
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"update %@ set ", tableName];
    NSMutableArray *argumentsArr = [NSMutableArray arrayWithCapacity:0];
    
    for (NSString *key in dic) {
        
        if (![clomnArr containsObject:key] || [key isEqualToString:@"pkid"]) {
            continue;
        }
        [finalStr appendFormat:@"%@ = %@,", key, @"?"];
        [argumentsArr addObject:dic[key]];
    }
    
    [finalStr deleteCharactersInRange:NSMakeRange(finalStr.length-1, 1)];
    if (where.length) [finalStr appendFormat:@" %@", where];
    
    
    flag =  [_db executeUpdate:finalStr withArgumentsInArray:argumentsArr];
    
    return flag;
}

/**
 查询数据

 @param tableName 表名称
 @param parameters 查询数据
 @param format 查询语句
 @return 查询内容
 */
- (NSArray *)ll_lookupTable:(NSString *)tableName dicOrModel:(id)parameters whereFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    NSMutableArray *resultMArr = [NSMutableArray arrayWithCapacity:0];
    NSDictionary *dic;
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"select * from %@ %@", tableName, where?where:@""];
    NSArray *clomnArr = [self getColumnArr:tableName db:_db];
    
    FMResultSet *set = [_db executeQuery:finalStr];
    
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
        
        while ([set next]) {
            
            NSMutableDictionary *resultDic = [NSMutableDictionary dictionaryWithCapacity:0];
            for (NSString *key in dic) {
                
                if ([dic[key] isEqualToString:SQL_TEXT]) {
                    id value = [set stringForColumn:key];
                    if (value)
                        [resultDic setObject:value forKey:key];
                } else if ([dic[key] isEqualToString:SQL_INTEGER]) {
                    [resultDic setObject:@([set longLongIntForColumn:key]) forKey:key];
                } else if ([dic[key] isEqualToString:SQL_REAL]) {
                    [resultDic setObject:[NSNumber numberWithDouble:[set doubleForColumn:key]] forKey:key];
                } else if ([dic[key] isEqualToString:SQL_BLOB]) {
                    id value = [set dataForColumn:key];
                    if (value)
                        [resultDic setObject:value forKey:key];
                }
                
            }
            
            if (resultDic) [resultMArr addObject:resultDic];
        }
        
    }else {
        
        Class CLS;
        if ([parameters isKindOfClass:[NSString class]]) {
            if (!NSClassFromString(parameters)) {
                CLS = nil;
            } else {
                CLS = NSClassFromString(parameters);
            }
        } else if ([parameters isKindOfClass:[NSObject class]]) {
            CLS = [parameters class];
        } else {
            CLS = parameters;
        }
        
        if (CLS) {
            NSDictionary *propertyType = [self modelToDictionary:CLS excludePropertyName:nil];
            
            while ([set next]) {
                
                id model = CLS.new;
                for (NSString *name in clomnArr) {
                    if ([propertyType[name] isEqualToString:SQL_TEXT]) {
                        id value = [set stringForColumn:name];
                        if (value)
                            [model setValue:value forKey:name];
                    } else if ([propertyType[name] isEqualToString:SQL_INTEGER]) {
                        [model setValue:@([set longLongIntForColumn:name]) forKey:name];
                    } else if ([propertyType[name] isEqualToString:SQL_REAL]) {
                        [model setValue:[NSNumber numberWithDouble:[set doubleForColumn:name]] forKey:name];
                    } else if ([propertyType[name] isEqualToString:SQL_BLOB]) {
                        id value = [set dataForColumn:name];
                        if (value)
                            [model setValue:value forKey:name];
                    }
                }
                
                [resultMArr addObject:model];
            }
        }
        
    }
    
    return resultMArr;
}

//删除表
- (BOOL)ll_deleteTable:(NSString *)tableName
{
    
    NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
    if (![_db executeUpdate:sqlstr])
    {
        return NO;
    }
    return YES;
}

//删除所有数据
- (BOOL)ll_deleteAllDataFromTable:(NSString *)tableName
{
    
    NSString *sqlstr = [NSString stringWithFormat:@"DELETE FROM %@", tableName];
    if (![_db executeUpdate:sqlstr])
    {
        return NO;
    }
    
    return YES;
}

//表是否存在
- (BOOL)ll_isExistTable:(NSString *)tableName
{
    
    FMResultSet *set = [_db executeQuery:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and name = ?", tableName];
    while ([set next])
    {
        NSInteger count = [set intForColumn:@"count"];
        if (count == 0) {
            return NO;
        } else {
            return YES;
        }
    }
    return NO;
}

//返回表中字段名
- (NSArray *)ll_columnNameArray:(NSString *)tableName
{
    return [self getColumnArr:tableName db:_db];
}

//表中多有少条数据
- (int)ll_tableItemCount:(NSString *)tableName
{
    
    NSString *sqlstr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", tableName];
    FMResultSet *set = [_db executeQuery:sqlstr];
    while ([set next])
    {
        return [set intForColumn:@"count"];
    }
    return 0;
}

- (void)close
{
    [_db close];
}

- (void)open
{
    [_db open];
}
- (BOOL)ll_alterTable:(NSString *)tableName dicOrModel:(id)parameters
{
    return [self ll_alterTable:tableName dicOrModel:parameters excludeName:nil];
}

- (BOOL)ll_alterTable:(NSString *)tableName dicOrModel:(id)parameters excludeName:(NSArray *)nameArr
{
    __block BOOL flag;
    [self ll_inTransaction:^(BOOL *rollback) {
        if ([parameters isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in parameters) {
                if ([nameArr containsObject:key]) {
                    continue;
                }
                flag = [self->_db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@", tableName, key, parameters[key]]];
                if (!flag) {
                    *rollback = YES;
                    return;
                }
            }
            
        } else {
            Class CLS;
            if ([parameters isKindOfClass:[NSString class]]) {
                if (!NSClassFromString(parameters)) {
                    CLS = nil;
                } else {
                    CLS = NSClassFromString(parameters);
                }
            } else if ([parameters isKindOfClass:[NSObject class]]) {
                CLS = [parameters class];
            } else {
                CLS = parameters;
            }
            NSDictionary *modelDic = [self modelToDictionary:CLS excludePropertyName:nameArr];
            NSArray *columnArr = [self getColumnArr:tableName db:self->_db];
            for (NSString *key in modelDic) {
                if (![columnArr containsObject:key] && ![nameArr containsObject:key]) {
                    flag = [self->_db executeUpdate:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@", tableName, key, modelDic[key]]];
                    if (!flag) {
                        *rollback = YES;
                        return;
                    }
                }
            }
        }
    }];
    
    return flag;
}
// =============================   线程安全操作    ===============================

- (void)ll_inDatabase:(void(^)(void))block
{
    
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        block();
    }];
}

- (void)ll_inTransaction:(void(^)(BOOL *rollback))block
{
    
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        block(rollback);
    }];
    
}

// 得到表里的字段名称
- (NSArray *)getColumnArr:(NSString *)tableName db:(FMDatabase *)db
{
    NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:0];
    
    FMResultSet *resultSet = [db getTableSchema:tableName];
    
    while ([resultSet next]) {
        [mArr addObject:[resultSet stringForColumn:@"name"]];
    }
    
    return mArr;
}


// 获取model的key和value
- (NSDictionary *)getModelPropertyKeyValue:(id)model tableName:(NSString *)tableName clomnArr:(NSArray *)clomnArr
{
    NSMutableDictionary *mDic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([model class], &outCount);
    
    for (int i = 0; i < outCount; i++) {
        
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        if (![clomnArr containsObject:name]) {
            continue;
        }
        
        id value = [model valueForKey:name];
        if (value) {
            [mDic setObject:value forKey:name];
        }
    }
    free(properties);
    
    return mDic;
}

#pragma mark - *******runtime

/**
 返回存储的字典key属性名称,value属性类型

 @param cls 结构体指针
 @param nameArr 过滤key的数组
 @return dic
 */
- (NSDictionary *)modelToDictionary:(Class)cls excludePropertyName:(NSArray *)nameArr
{
    
    NSMutableDictionary * mDic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int outCount;
    //获取属性列表
    objc_property_t * properties = class_copyPropertyList(cls, &outCount);
    for (int i = 0; i<outCount; i++) {
        //获取名称
        NSString * name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
       //过滤不可添加key
        if ([nameArr containsObject:name]) continue;
        //获取属性类型
        NSString * type = [NSString stringWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        //属性类型转化成数据库类型
        id value = [self propertTypeConvert:type];
        if (value) {
            [mDic setObject:value forKey:name];
        }
        
        
    }
    free(properties);
    return mDic;
}

/**
 str

 @param typeStr 属性类型
 @return 数据库类型
 */
- (NSString *)propertTypeConvert:(NSString *)typeStr
{
    NSString *resultStr = nil;
    if ([typeStr hasPrefix:@"T@\"NSString\""]) {
        resultStr = SQL_TEXT;
    } else if ([typeStr hasPrefix:@"T@\"NSData\""]) {
        resultStr = SQL_BLOB;
    } else if ([typeStr hasPrefix:@"Ti"]||[typeStr hasPrefix:@"TI"]||[typeStr hasPrefix:@"Ts"]||[typeStr hasPrefix:@"TS"]||[typeStr hasPrefix:@"T@\"NSNumber\""]||[typeStr hasPrefix:@"TB"]||[typeStr hasPrefix:@"Tq"]||[typeStr hasPrefix:@"TQ"]) {
        resultStr = SQL_INTEGER;
    } else if ([typeStr hasPrefix:@"Tf"] || [typeStr hasPrefix:@"Td"]){
        resultStr= SQL_REAL;
    }
    
    return resultStr;
}
@end
