GalaxieCache is a wickedly fast custom tag that saves generated partial page content as a static page to the file system or RAM. Depending on your usage, GalaxieCache is one of the fastest caching solutions and uses native ColdFusion and Lucee cfinclude's to render the content.

In its simplest form, GalaxieCache reads the file property and tests to see if the specified file exists, and if it does, uses a cfinclude to render the page and exits the template. You can't get faster than this!

* * *

Table of Contents
-----------------

*   [Background](#mcetoc_1j30ce75hj) 
*   [Simple Examples](#mcetoc_1j30ce75hk)
*   [Brief Description](#mcetoc_1j30ce75hl) 
*   [Arguments](#mcetoc_1j30ce75hm)
    *   [name or cacheName (one of these is required)](#mcetoc_1j30ce75hn)
    *   [scope (required)](#mcetoc_1j30ce75ho)
    *   [file (only used when scope is set to html or file)](#mcetoc_1j30ce75hp)
    *   [fileType (only used when the scope is set to file)](#mcetoc_1j30ce75hq)
    *   [timeout (optional)](#mcetoc_1j30ce75hr)
    *   [disabled (optional)](#mcetoc_1j30ce75hs)
    *   [clear (optional)](#mcetoc_1j30ce75ht)
    *   [clearAll (optional)](#mcetoc_1j30ce75hu)
    *   [cacheDirectory (only used with clearAll)](#mcetoc_1j30ce75hv)
    *   [debug](#mcetoc_1j30ce75h10)
*   [Considerations When Using HTML](#mcetoc_1j30ce75h11)
    *   [Instead of Using Timeouts,  Use Events to Manage Files and Refresh Content](#mcetoc_1j30ce75h12)
        *   [The flushGalaxieCacheFiles Function:](#mcetoc_1j30ce75h13)
        *   [Function Usage Example](#mcetoc_1j30ce75h14)
    *   [If you can't Refresh Content Using Events, use a Different Scope if the Content Requires Frequent Changes.](#mcetoc_1j30ce75h15)

* * *

Background
----------

* * *

GalaxieCache is a modern fork of [ScopeCache](https://www.raymondcamden.com/2004/01/08/F729C572-BF2B-430C-525FCCF58760CAD5), which [Ray Camden](https://www.raymondcamden.com/) created. I have personally experienced a _10-15% improvement over scopeCache_, which this is based upon, and a _5-10% performance improvement over using the [cfcache](https://helpx.adobe.com/coldfusion/cfml-reference/coldfusion-tags/tags-c/cfcache.html) tag_ when using [cfincludes](https://helpx.adobe.com/coldfusion/cfml-reference/coldfusion-tags/tags-i/cfinclude.html). There is virtually no overhead when using cfincludes, as ColdFusion and Lucee essentially copy the content of the included template to the page. Other than invoking the GalaxieCache custom tag, which on average takes slightly over 1 millisecond, there is no additional overhead after the content is initially generated.

Like ScopeCache, GalaxieCache also supports caching the content to RAM using either the server, application, or session [scopes](https://helpx.adobe.com/coldfusion/developing-applications/developing-cfml-applications/using-persistent-data-and-locking/about-persistent-scope-variables.html). These scopes define the lifespan of the stored cache. You can also store the content on disk using scope='file'; however, this is the slowest available method because file system operations can be expensive.

GalaxieCache also supports a timeout argument, which will refresh the content after a given datetime or set period of time, and there is an optional debugging carriage that allows the developer to inspect what is going on under the hood. Finally, unlike using the cfcache tag, which has issues when used with Lucee, GalaxieCache also seamlessly works with both Lucee and Adobe ColdFusion using identical logic.

Installation
------------

* * *

To install GalaxieCache, download the files from the GitHub Repo at [https://github.com/GregoryAlexander77/GalaxieCache](https://github.com/GregoryAlexander77/GalaxieCache) and save the [galaxieCache.cfm](https://github.com/GregoryAlexander77/GalaxieCache/blob/main/galaxieCache.cfm) template to your preferred custom tag directory. 

There are multiple ways to invoke and store custom tags. I personally store this tag in a tags directory and invoke galaxieCache using a [cfmodule](https://helpx.adobe.com/coldfusion/cfml-reference/coldfusion-tags/tags-m-o/cfmodule.html) tag. Choose whatever method you think best. See [https://helpx.adobe.com/coldfusion/developing-applications/building-blocks-of-coldfusion-applications/creating-and-using-custom-cfml-tags/creating-custom-tags.html](https://helpx.adobe.com/coldfusion/developing-applications/building-blocks-of-coldfusion-applications/creating-and-using-custom-cfml-tags/creating-custom-tags.html) for more information.

You should also save the function within the [flushGalaxieCacheFiles.cfm](https://github.com/GregoryAlexander77/GalaxieCache/blob/main/flushGalaxieCacheFiles.cfm) template to handle the cached files using your own custom events. We will explain how to achieve this later in this article.

GalaxieCache on GitHub

* * *

Simple Example
--------------

* * *

To cache content that uses a cfinclude, simply wrap the content using a tag or a cfmodule. Using a cfmodule is a better approach as it provides isolation and ensures that there is no contention between outside variables. Here are some simple examples:

* * *

    <cfmodule template="galaxieCache.cfm" cachename="example" scope="file" fileType="html" file="#application.baseUrl#/test/example.cfm">
    <p>Simple GalaxieCache Example on <cfoutput>#dateFormat(now())</cfoutput>#</p>
    </cfmodule>

* * *

Since GalaxieCache is a custom tag, there are other ways to cache page content. You can use something like this:

* * *

    <cf_galaxieCache cachename="example" scope="html" file="#application.baseUrl#/test/example.cfm">
    <p>Simple GalaxieCache Example on <cfoutput>#dateFormat(now())</cfoutput>#</p>
    </cf_galaxieCache>

* * *

Note: you can also use cfimport. See [https://helpx.adobe.com/coldfusion/developing-applications/building-blocks-of-coldfusion-applications/creating-and-using-custom-cfml-tags/creating-custom-tags.html](https://helpx.adobe.com/coldfusion/developing-applications/building-blocks-of-coldfusion-applications/creating-and-using-custom-cfml-tags/creating-custom-tags.html) for more information.

* * *

Brief Description
-----------------

* * *

To use GalaxieCache, wrap the content that you want to be cached between two custom tags as shown above. The first time that the tag is run, GalaxieCache captures the content between the two tags and uses the cacheName argument to save the content to the file system or RAM, depending upon the supplied scope argument. Once the tag is hit again, GalaxieCache retrieves the saved content from the file system or RAM and renders the content.

* * *

Arguments
---------

* * *

### name or cacheName (one of these is required)

* * *

The name or cacheName specifies the key that the structure is stored in. You should use cacheName instead of name when using a cfmodule.

This name is used to create a cached key and it is dyanmic. A new cache item will be created for each unique key. For example, in Galaxie Blog, I have nearly 40 different themes and I append a themeId to the name in order to create unique cached content tailored to each theme. You can also use dynamic URL variables like so:

* * *

    <cfset cacheName = "testHtml=" & URL.themeId>
    <cfmodule template="#application.baseUrl#/tags/galaxieCache.cfm" cachename="#cachename#" scope="file" fileType="html" file="#application.baseUrl#/cache/posts/#cacheName#.cfm" debug="true" disabled="false">
    This cache is unique to the <cfoutput>#URL.themeName#</cfoutput>
    </cfmodule>

* * *

### scope (required)

* * *

GalaxieCache will store the data in the following scope, determined by the required **scope** argument. The following scopes are available:

*   **html**  
    GalaxieCache will grab the content between the tags and store the generated data in the file system as a static HTML file. This method uses a cfinclude to render the content and is optimal for content that does not need to be changed often.
*   **server**  
    Content will be stored within a structure using ColdFusion's or Lucee's server scope. The server scope provides the longest living data outside of the file scope, and cached data should persist until the server is restarted.
*   **application**  
    The content will be stored in a structure in ColdFusion's or Lucee's application scope. The cache will be refreshed when the application times out or the server is restarted. This is the best scope to use when you're not in charge of the content and it changes frequently on a set interval. 
*   **session  
    **The cache is available to individual session scopes. This is the shortest-lived scope and should not be used if you want a long cache duration.
*   **html**  
    GalaxieCache will store the data in the file system as a JSON or XML-based file, depending on the **fileType** HTML argument. We will cover the fileType setting in the section below.

* * *

### file (only used when scope is set to html or file)

* * *

Specify the **_relative_** file name used for storing content on the file system (i.e., '/blog/cache/example.cfm'). This argument is necessary when the scope argument is set to html or file.

If you're using scope='file' or scope='html', since you may need to delete the files to recreate the cached, _it is vital to create an independent directory where it does not impact other files_. I personally create a cache directory within the root of the application and only use it for GalaxieCache files.

* * *

### fileType (only used when the scope is set to file)

* * *

The **fileType** argument is only used when the scope is set to file. There are two different fileTypes available:

*   **json  
    **Stores the generated content as JSON in the file system. This is an efficient storage method that conserves space on the file system but requires that the content be decoded when rendered.
*   **wddx  
    **Similar to JSON, however, the data within the structure is saved using the deprecated WDDX format.

* * *

### timeout (optional)

* * *

This argument is used to determine when the content should be refreshed. This can be a date or the number of seconds when the content is to expire. For example, I use #(60\*30)# to continuously refresh Galaxie Blogs cfblogs.org ColdFusion/Lucee content on the sidebar every 30 minutes. 

Unless timeout value has been removed or changed in your code, this timeout value will persist even when the server is restarted to ensure that the content continues to be refreshed.

* * *

### disabled (optional)

* * *

Disabled is a Boolean argument that allows the caching engine to be temporarily disabled. When set to true, the tag exits and all content between the tags will be rendered as if the custom tag did not exist. I personally use this when I want to preview new content.

* * *

### **clear** (optional)

* * *

If clear is set to true, the key within the structure or file will be deleted and no longer exist. If you're saving content to the file system and want to delete the file, you must also specify the relative path to the file in the file argument.

* * *

### clearAll (optional)

* * *

When set to true, this will delete **all** of the cached items. Requires a relative path to be specified in the **cacheDirectory** argument to delete all of the cache files inside a given directory.

* * *

### **cacheDirectory (only used with clearAll)**

* * *

Only used when you use clearAll and want to clear all files within a given directory. Requires a relative path to the directory.  
_Be careful when using this argument; otherwise, you may delete wanted files!_

* * *

### debug

* * *

Setting the debug argument to true allows developers to print out the activity of each step of the process for debugging purposes. 

* * *

Considerations When Using scope='html'
--------------------------------------

* * *

Using scope='html' is one of the fastest methods available _anywhere_ to cache ColdFusion/Lucee partial page fragments. However, due to the initial file overhead when saving the generated content to disk, you should consider using events to manage files. If you are not in control of the events that change the dynamic content, and you need to refresh the content using a set interval frequently, consider using the application scope instead.

* * *

### Instead of Using Timeouts,  Use Events to Manage Files and Refresh Content

I developed the function below to delete the static files and use it when certain events occur, such as making a blog comment or a post. This allows me to delete the cached files in my unique cache directory. Once the files are deleted, GalaxieCache will rebuild the cache using fresh content.

* * *

Note: I am using a function to manage the content instead of putting this logic inside the GalaxieCache custom tag to eliminate the slight overhead when using a custom tag and to prevent potential file locking. I also want to use the GalaxieCache custom tag to process the cache, preferably without doing anything else. This function supports additional arguments, such as filter, which allows it to query the cached files. 

* * *

#### The flushGalaxieCacheFiles Function:

* * *

    <cffunction name="flushGalaxieCacheFiles" access="public" returntype="boolean" output="false"
    		hint="Loops through files and deletes the cache files in a directory using the file name or a filter. When using GalaxieCache, the file name will be the name of the cache. Returns a boolean value to indicate if the function was run. Important note- for safety, you should only store the cache files in their own dedicated directory.">
    	<cfargument name="directory" type="string" required="true" />
    	<!--- Files that match a fileName or filter will be deleted. To delete all of the cache files in a directory, don't supply a string. --->
    	<cfargument name="fileFilter" type="string" default="" required="false" />
    	<!--- Set to true if you want to recursively delete files --->
    	<cfargument name="recursive" type="boolean" default="false" required="false" />
    
    	<!--- Note: be careful if you don't specify a fileFilter as you may delete all of the files in a directory. If they are cache files, it is not a huge deal as they will be recreated again when someone visits a page when using Galaxie Cache. --->
    	<cfif len(arguments.fileFilter)>
    		<!--- Get the files that match the supplied file name or filter. --->
    		<cfdirectory action="list" directory="#expandPath('#arguments.directory#')#" recurse="#arguments.recursive#" filter="*#arguments.fileFilter#*" name="cacheFiles"/>
    	<cfelse>
    		<!--- Get all of the files within the directory --->
    		<cfdirectory action="list" directory="#expandPath('#arguments.directory#')#" recurse="#arguments.recursive#" name="cacheFiles"/>
    	</cfif>
    	<!--- Loop through the files found in the directory. --->
    	<cfloop query="cacheFiles">
    		<cflock name="#arguments.directory#" type="exclusive" timeout="30">
    			<cffile action="delete" file="#expandPath(arguments.directory)#/#name#" />
    		</cflock>
    	</cfloop>
    
    	<cfreturn 1>
    </cffunction>	

* * *

#### Function Usage Example

* * *

The following code is used in Galaxie Blog when an administrator updates a blog post. Here, I set the cache directory used by posts ('/blog/cache/posts') and specify a filter that will delete all of the cached files that match 'postId=xxx'. After the file is deleted, GalaxieCache will automatically render the new post content and save it to the filesystem again.

* * *

    <!--- Clear the posts that use this postId --->
    <cfset thisDirectory = application.baseUrl & '/cache/posts'>
    <!--- This filter will match all posts that use the postId --->
    <cfset thisFileNameOrFilter = 'postId=' & arguments.postId>
    <!--- Delete the files --->
    <cfset flushGalaxieCacheFiles(thisDirectory,thisFileNameOrFilter)>
    
    <!--- Delete the comment files associated with this post --->
    <cfset thisDirectory = application.baseUrl & '/cache/comments'>
    <cfset thisFileNameOrFilter = 'commentPostId=#arguments.postId#'>
    <!--- Delete the files --->
    <cfset flushGalaxieCacheFiles(thisDirectory,thisFileNameOrFilter)>

* * *

### If you can't Refresh Content Using Events, use a Different Scope if the Content Requires Frequent Changes.

* * *

Although HTML offers fast performance, this method still requires generating the initial content and saving it to the filesystem, which slows down performance. If your content requires constant changes and you can't use events to refresh it, you may want to consider using a different scope instead.

For example, Galaxie Blog displays the content of all new ColdFusion and Lucee blog posts. To display these posts, I programmatically check various RSS feeds every few minutes. Since I don't control the timing of the new posts and can't use events to refresh this content- for the CFBlogs feed, I use GalaxieCache with the application scope instead.
