<!---
	Name         : galaxieCache.cfm
	Author       : Gregory Alexander. Based upon the scopeCache library authored by Raymond Camden. 
				 : Gregory Alexander *completely* overhauled the original scopeCache logic and added debugging cariages, JSON, and HTML file formats when storing the data in files.
	Purpose		 : Allows you to cache content in various scopes.
	
	This tag allows you to cache content and data in various RAM-based scopes. 
	The tag takes the following attributes:

	name/cachename:	The name of the data. Either name or cacheName is required. Use cacheName when using a cfmodule tag (required)
	scope: 			The scope where cached data will reside. Must be either session, 
					application, server, or file. (required)
	fileType:		We can store the data as a WDDX packet, JSON, or HTML when the scope is set to 'file'. 
					HTML is the most efficient and uses a simple cfinclude to output the data, however, it uses more disk space on the server. 
	file:			Fully qualified file name for file-based caching. Only used when the scope is set to 'file'.
	timeout: 		When the cache will timeout. By default, the year 3999 (i.e., never). 
					Value must be either a date/time stamp or a number representing the
					number of seconds until the timeout is reached. Use 0 if you want an immediate timeout to reset the cache data (optional)
	dependancies:	This allows you to mark other cache items as dependant on this item. 
					When this item is cleared or times out, any child will also be cleared.
					Also, any children of those children will also be cleared. (optional)
	clear:			If passed and if true, will clear out the cached item. Note that
					This option will NOT recreate the cache. In other words, the rest of
					the tag isn't run (well, mostly, but dont worry).
	clearAll:		Removes all data from this scope. Exits the tag immediately.
	cacheDirectory: The cache directory where the cached files reside is required if you're using clearAll and 
					you want to delete all of the cached files when using file and fileType html.
	disabled:		Allows for a quick exit out of the tag. How would this be used? You can 
					imagine using disabled="#request.disabled#" to allow for a quick way to
					turn on/off caching for the entire site. Of course, all calls to the tag
					would have to use the same value.
	getCacheItems:	Returns a list of keys in the cache. The tag exists when called. 
					NOTICE! Some items may have expired. Items are only removed when you are fetching or clearing them.
	getCacheData:	Returns the value directly.
	
	suppressHitCount: Only used for file operations - if passed, we dont bother updating the file based cache with the hit count. Makes the file IO a bit less.

	License: 		Uses the Apache2 license.

	When the tag is processed, we output the data at the start of tag execution and create the structure upon completion of template execution.

	Example usage with cfmodule:
	<cfmodule template="../../tags/galaxieCache.cfm" scope="application" cachename="#cacheName#" timeout="#(60*60)#" disabled="#application.disableCache#">
		...Code...
	</cfmodule>
--->

<!--- Either the name or cachename is required. --->
<cfparam name="attributes.name" default="" type="string">
<!--- Cachename is used when using cfmodule --->
<cfparam name="attributes.cachename" default="" type="string">
<!--- Scope defaults to application --->
<cfparam name="attributes.scope" default="application" type="string">
<!--- Renders the data from the cache or from the content between the tags (or cfmodules). This argument is necessary because you may need to reset the cache without rendering the page, for instance, when a revised blog post is published and you only want to update the cache data. --->
<cfparam name="attributes.renderCacheData" default="true" type="boolean">
<!--- Returns a list of keys in the cache. The tag exits when called. --->
<cfparam name="attributes.getCacheData" default="false" type="boolean">
<!--- The structure may be stored in a file using the WDDX format --->
<cfparam name="attributes.file" default="" type="string">
<!--- The fileType is either: wddx, json or html. Using HTML uses a cfinclude and should be the fastest operation --->
<cfparam name="attributes.fileType" default="html" type="string">
<!--- Default dependancy list --->
<cfparam name="attributes.dependancies" default="" type="string">
<!--- suppressHitCount is turned off by default; however, I am suppressing the hit count when the file type is set to HTML, as keeping it will consume more resources. When using HTML includes and want to increment the hit count, you must supply a timeout in the tag or module. --->
<cfparam name="attributes.suppressHitCount" default="false" type="boolean">
<!--- The default timeout is no timeout, so we use the year 3999. We will have flying cars then. --->
<cfparam name="attributes.timeout" default="#createDate(3999,1,1)#">
<!--- Disabled allows users to automatically exit the tag --->
<cfparam name="attributes.disabled" default="false" type="string">
<!--- Used to clear an item from the cache. Requires the file if the cache is file and the fileType is html --->
<cfparam name="attributes.clear" default="false" type="boolean">
<!--- Used to clear all items from the cache. Requires the cacheDirectory if you want to delete all of the files within a cache directory when using file with the fileType of html --->
<cfparam name="attributes.clearAll" default="false" type="boolean">
<!--- Specify the cacheDirectory if you want to clear the HTML-based file cache. --->
<cfparam name="attributes.cacheDirectory" default="" type="string">
<!--- Debug prints the process on the page --->
<cfparam name="attributes.debug" default="false" type="boolean">
<!--- Allows you to visualize the structure that is created --->
<cfparam name="attributes.dumpStruct" default="false" type="boolean">
	
<cfif attributes.debug>
	<cfset debug = 1> 
<cfelse>
	<cfset debug = 0> 
</cfif>

<cfif attributes.dumpStruct>
	<cfset dumpStruct = 1> 
<cfelse>
	<cfset dumpStruct = 0> 
</cfif>

<cfif debug>
	<br/>Debug mode<br/>
	Current time (on server): <cfoutput>#now()#</cfoutput><br/>
</cfif>

<!--- This variable will store all the guys we need to update --->
<cfset cleanup = "">
<!--- This variable determines if we run the caching. This is used when we clear a cache --->
<cfset processCache = true>
	
<cfif thisTag.executionMode eq "start">
	<!--- ****************************************************************************************************************
		Validation
	******************************************************************************************************************--->
	
	<!--- allow for quick exit --->
	<cfif attributes.disabled>
		<cfif debug>
			Exiting template<br/>
		</cfif>
		<cfexit method="exitTemplate">
	</cfif>
	
	<!--- Validation --->
	<!--- Sync the name and cacheName values to allow cachename in case we use cfmodule --->
	<cfif len(attributes.cacheName) and !len(attributes.name)>
		<cfset attributes.name = attributes.cacheName>
	</cfif>

	<!--- Validate the cache name --->
	<cfif !len(attributes.name) or !isSimpleValue(attributes.name)>
		<cfthrow message="galaxieCache: The name or cacheName attribute must be passed as a string.">
	</cfif>

	<!--- Scope is required and must be a valid value. --->
	<cfif !isSimpleValue(attributes.scope) or not listFindNoCase("application,session,server,file",attributes.scope)>
		<cfthrow message="galaxieCache: The scope attribute must be passed as one of: application, session, server, or file.">
	</cfif>

	<!--- Set the timeout value --->
	<cfif not isDate(attributes.timeout) and (not isNumeric(attributes.timeout) or attributes.timeout lt 0)>
		<cfthrow message="galaxieCache: The timeout attribute must be either a date/time or a number.">
	<cfelseif isNumeric(attributes.timeout)>
		<!--- convert seconds to a time --->
		<cfset attributes.timeout = dateAdd("s",attributes.timeout,now())>
		<cfif debug>
			Timeout value is numeric and is set to <cfoutput>#attributes.timeout#</cfoutput><br/>
		</cfif>
	</cfif>

	<!--- Require a file name when the scope is set to file (new logic added by Gregory) --->
	<cfif attributes.scope eq "file" and (attributes.file eq "")>
		<cfthrow message="galaxieCache: A file name is required when the scope is file.">
	</cfif>

	<!--- Set flags to determine where the scope is actually stored. If we are using HTML includes using the fileType argument of HTML, we will store the structure using the server scope. If the scope argument is file and the fileType is not html, we store the structure within a file. Otherwise the structure will be set to the scope arguments which can be server, application, or sesssion. --->
	<cfif attributes.scope eq "file" and attributes.fileType eq 'html'>
		<cfset useHtmlInclude = true>
	<cfelse>
		<cfset useHtmlInclude = false>
	</cfif>

	<!--- Dump the struct for visualization --->
	<cfif debug and dumpStruct and getColdFusionStructScope() neq 'none'>
		<!--- Dump the structure. --->
		<cfset scopeStruct = structGet(getColdFusionStructScope())>
		<cfdump var="#scopeStruct#" label="Current #getColdFusionStructScope()# vars">
	</cfif>
			
	<!--- ****************************************************************************************************************
		Initial Logic
	******************************************************************************************************************--->
	<cfif debug>
		Begin initial <cfoutput>#attributes.scope#</cfoutput> <cfif attributes.scope eq 'file'>and <cfoutput>#attributes.fileType#</cfoutput></cfif> scope logic for <cfoutput>#attributes.cacheName#</cfoutput><br/>
		Setting pointer to <cfoutput>#getColdFusionStructScope()#</cfoutput> scope<br/>
	</cfif>
			
	<!--- Determine if the structure needs to be initialized. This is not necessary when the scope is set to file and the fileType is not html as there will be no structure set in an actual ColdFusion scope --->	
	<cfif (getColdFusionStructScope() neq 'none')>  
		<!--- Get the ColdFusion/Lucee native structure --->
		<cfset scopeStruct = structGet(getColdFusionStructScope())>
		<!--- Determine if we should create the cache structure --->
		<cflock scope="#getColdFusionStructScope()#" type="readOnly" timeout="30">
			<cfif structKeyExists(scopeStruct,"galaxieCache")>
				<cfset needInit = false>
			<cfelse>
				<cfset needInit = true>
			</cfif>
		</cflock>
	</cfif>
	
	<!--- Create a pointer to our structure if it does not exist --->
	<cfif needInit>
		<cfif debug>
			Creating initial galaxieCache structure<br/>
		</cfif>

		<cflock scope="#getColdFusionStructScope()#" type="exclusive" timeout="30">
			<!--- check twice in case another thread finished --->
			<cfif not structKeyExists(scopeStruct,"galaxieCache")>
				<cfset scopeStruct["galaxieCache"] = structNew()>
			</cfif>
		</cflock>
	</cfif><!---<cfif needInit>--->
			
	<!--- ****************************************************************************************************************
		Pre-Processing and cleanup
	******************************************************************************************************************--->

	<!--- Dump the keys to the caller scope --->
	<cfif structKeyExists(attributes,"getCacheItems") and attributes.getCacheItems>
		<cfset caller[attributes.getCacheItems] = structKeyList(scopeStruct.galaxieCache)>
		<cfexit method="exitTag">
	</cfif>
			
	<!--- Do they want to nuke it all? --->
	<cfif attributes.clearAll>
		<cfif debug>
			Clearing cache<br/>
		</cfif>

		<!--- When serving static files, delete the files in the cache directory --->
		<cfif len(attributes.cacheDirectory)>
			<cfdirectory action="list" name="clearCacheDirectory" directory="#expandPath(attributes.cacheDirectory)#" recurse="true" />
			<cfloop query="clearCacheDirectory">
				<cfif clearCacheDirectory.type eq "file">
					<cflock name="#attributes.cacheDirectory#" type="exclusive" timeout="30">
						<cffile action="delete" file="#expandPath(attributes.cacheDirectory)##clearCacheDirectory.name#" />
					</cflock>
					<cfif debug> 
						Deleted <cfoutput>#attributes.cacheDirectory##clearCacheDirectory.name#</cfoutput><br/>
					</cfif>
				</cfif>
			</cfloop>
		</cfif><!---<cfif len(attributes.cacheDirectory)>--->
		
		<!--- Delete all the galaxieCache scopes in memory --->
		<cfset scopes = 'server,application,session'>
		<cfloop list="#scopes#" index="thisScope">
			<!--- Get the structure --->
			<cfset galaxieStruct = structGet(thisScope)>
			<!--- Delete this structure if exists --->
			<cflock scope="#thisScope#" type="readOnly" timeout="30">
				<cfif structKeyExists(galaxieStruct,"galaxieCache")>
					<cfset structDelete(galaxieStruct,"galaxieCache")>
					<cfif debug> 
						Deleted galaxieCache in <cfoutput>#thisScope#</cfoutput> scope<br/>
					</cfif>
				</cfif>
			</cflock>
		</cfloop> 

		<!--- Exit tag --->
		<cfexit method="exitTag">
	</cfif>

	<!--- Clear the cache if necessary --->
	<cfif attributes.clear>
		<cfif debug>
			Clearing cache<br/>
		</cfif>

		<!--- Delete the file when we store the structure to the file system. --->
		<cfif debug>
			File exists? <cfoutput>#fileExists(expandPath(attributes.file))#</cfoutput><br/>
		</cfif>
		<cfif fileExists(expandPath(attributes.file))>
			<cfif debug>
				Deleting file<br/>
			</cfif>
			<!--- Delete the file --->
			<cflock name="#attributes.file#" type="exclusive" timeout="30">
				<cffile action="delete" file="#expandPath(attributes.file)#">
			</cflock>
		</cfif>

		<!--- Cleanup the structure. Note: We need to clean up the metadata on the server scope when using static HTML. --->
		<cfif attributes.fileType neq 'html'>
			<!--- Delete the structure and clean up dependencies --->
			<cfset cleanup = scopeStruct.galaxieCache[attributes.name].dependancies>
			<cfset structDelete(scopeStruct.galaxieCache,attributes.name)>
		</cfif>
		<!--- Exit tag --->
		<cfexit method="exitTag">
	</cfif><!---<cfif attributes.clear>--->
				
</cfif><!---<cfif thisTag.executionMode eq "start">--->

<!--- ****************************************************************************************************************
	Process the cache
******************************************************************************************************************--->
<!--- Process the cache --->
<cfif processCache>
	<cfif debug>
		Processing cache using <cfoutput>#attributes.scope#</cfoutput> scope<br/>
	</cfif>
	<!--- ****************************************************************************************************************
		Start Execution
	******************************************************************************************************************--->
	<cfif thisTag.executionMode eq "start">
		<cfif debug>
			Execution start<br/>
		</cfif>
		<!--- ******************************************************************
			Process Files
		********************************************************************--->
		<cfif attributes.scope eq "file" and attributes.renderCacheData>
			
			<!--- ************************* HTML Includes *************************--->
			<!--- Read the metadata in the server scope if it exists. HTML files will be stored in the server scope if there is a specified timeout; otherwise, the files will be stored on the server until manually cleared out. --->
			<cfif useHtmlInclude>
				
				<!--- For html includes, we are *only* storing data in server scope when there is a timeout. If there is no time out, I will permanently  store the html on the server and it needs to be manually cleaned up when necessary. --->
				<cfif structKeyExists(scopeStruct.galaxieCache, attributes.name) and 
					  structKeyExists(scopeStruct.galaxieCache[attributes.name],"timeout")>
					<cfset htmlIncludeTimeout = scopeStruct.galaxieCache[attributes.name].timeout>
					<cfset indefinateHtmlTimeout = false>
				<cfelse>
					<!--- Expire it when we have flying cars --->
					<cfset htmlIncludeTimeout = createDate(3999,1,1)>
					<cfset indefinateHtmlTimeout = true>
					<!--- And suppress the hit count as there will be no meta-data in the server scope to process --->
					<cfset attributes.suppressHitCount = true>
				</cfif>
					
				<cfif debug>
					Processing scoped structure<br/>
					<cfif dateCompare(now(),htmlIncludeTimeout) eq -1>
						Cache is valid<br/>
					<cfelse>
						Cache is expired<br/>
					</cfif>
				</cfif>

				<!--- Is the current date less than the timeout? --->
				<cfif dateCompare(now(),htmlIncludeTimeout) eq -1>
					<cfif debug>
						<cfoutput>dateCompare(now(),htmlIncludeTimeout):#dateCompare(now(),htmlIncludeTimeout)#</cfoutput>
						Cache valid and expires at <cfoutput>#htmlIncludeTimeout#</cfoutput><br/>
					</cfif>

					<!--- Does the file currently exist? --->
					<cfif fileExists(expandPath(attributes.file))>
						<cfif debug>
							The file exists<br/>
						</cfif>

						<!--- We have to read the filie if the user wants to get the cached data. --->
						<cfif attributes.getCacheData>
							<cfif debug>
								Reading saved file<br/>
							</cfif>
							<!--- Read the file --->
							<cflock name="#attributes.file#" type="readonly" timeout="30">
								<cffile action="read" file="#expandPath(attributes.file)#" variable="contents" charset="UTF-8">
							</cflock>
							<cfif debug and dumpStruct>
								<cfdump var="#contents#" label="contents">
							</cfif>
							<!--- Send the content back to the client --->
							<cfset caller[attributes.getCacheData] = contents>
						<cfelse><!---<cfif attributes.getCacheData>--->
							<cfif debug>
								Including the file<br/>
							</cfif>
							<!--- Simply include the file --->
							<cfinclude template="#attributes.file#">
						</cfif><!---<cfif attributes.getCacheData>--->
								
						<cfif !attributes.suppressHitCount>
							<cfif debug>
								Updating hit count<br/>
							</cfif>

							<!--- When using HTML, the hit count is stored in metadata in the server scope. --->
							<cflock scope="server" type="exclusive" timeout="30">
								<!--- Increment the hit count --->
								<cfset scopeStruct.galaxieCache[attributes.name].hitCount = scopeStruct.galaxieCache[attributes.name].hitCount + 1>
							</cflock>	
						</cfif><!---<cfif !attributes.suppressHitCount>--->
								
						<!--- Note: only exit if the file exists and after including the file. Otherwise, no content will be displayed and the file will not initially be saved. --->
						<cfif debug>
							Exiting tag after including file<br/>
						</cfif>
						<cfexit method="exitTag">
					</cfif><!---<cfif fileExists(expandPath(attributes.file))>--->

				</cfif><!---<cfif structKeyExists(scopeStruct.galaxieCache, attributes.name)>--->
				
			</cfif><!---<cfif useHtmlInclude and structKeyExists(scopeStruct.galaxieCache, attributes.name)>--->
			
			<!--- Process the structure when it's stored to the file system --->
			<cfif !useHtmlInclude and 
				structKeyExists(scopeStruct.galaxieCache[attributes.name],"hitcount")>
				
				<cfif debug>
					Reading saved file<br/>
				</cfif>
				
				<!--- Read the saved file if it exists. If it doesn't, we will save it later on --->
				<cfif fileExists(expandPath(attributes.file))>
					<cfif debug>
						File exists<br/>
					</cfif>
					
					<!--- Read the file in to check metadata --->
					<cflock name="#attributes.file#" type="readonly" timeout="30">	
						<!--- Read the file --->
						<cffile action="read" file="#expandPath(attributes.file)#" variable="contents" charset="UTF-8">
					</cflock>
						
					<!--- Prepare the data. Make sure to validate the data as the user can change the fileType and it will cause errors if the file is not formatted correctly --->
					<cfif attributes.fileType eq 'wddx' and isWddx(contents)>
						<!--- Convert the WDDX packet to CFML --->
						<cfwddx action="wddx2cfml" input="#contents#" output="data">
					<cfelseif attributes.fileType eq 'json' and isJson(contents)>
						<!--- DeSerialize the JSON --->
						<cfset data = deserializeJSON(contents)>
					</cfif>
						
					<cfif debug and dumpStruct>
						<cfdump var="#Data#" label="Data">
					</cfif>
					
					<!--- Output the cache content if the current date is less than the timeout. The timeout key in the structure may not exist if the file can't be read. This may occur when the file has been uploaded to the server and the user changes the fileType again --->
					<cfif dateCompare(now(),data.timeout) is -1> 
						<cfif debug>
							Cache is valid and expires at <cfoutput>#data.timeout#</cfoutput><br/>
						</cfif>
						<cfif attributes.getCacheData>
							<!--- Send the cache data back to the client --->
							<cfset caller[attributes.getCacheData] = data.value>
						<cfelse>
							<cfif debug>
								Outputting contents of file<br/>
							</cfif>
							<!--- Render the data from the file --->
							<cfoutput>#data.value#</cfoutput>
						</cfif>
								
						<cfif !attributes.suppressHitCount>
							<cfif debug>
								Updating hit count in file<br/>
							</cfif>
							
							<cflock name="#attributes.file#" type="exclusive" timeout="30">
								<!--- Increment the hit count. Note: I suppress the hitcount when using html --->
								<cfset data.hitCount = data.hitCount + 1>
								<!--- Save the file --->
								<cfif attributes.fileType eq 'wddx'>
									<!--- Convert the CFML packet to WDDX --->
									<cfwddx action="cfml2wddx" input="#data#" output="packet">
								<cfelseif attributes.fileType eq 'json'>
									<!--- Serialize JSON --->
									<cfset packet = serializeJSON(data)>
								</cfif>
								<!--- Save the file --->
								<cflock name="#attributes.file#" type="exclusive" timeout="30">
									<cffile action="write" file="#attributes.file#" mode="755" output="#packet#" charset="UTF-8">	
								</cflock>
							</cflock>
						</cfif><!---<cfif !attributes.suppressHitCount>--->
										
						<cfif debug>
							Exiting tag after processing file<br/>
						</cfif>
						<cfexit method="exitTag">						
					</cfif><!---<cfif dateCompare(now(),data.timeout) is -1>--->
										
				</cfif><!---<cfif fileExists(expandPath(attributes.file))>--->
									
			</cfif><!---<cfif attributes.fileType eq "html">--->
		
		<!--- ******************************************************************
			Process Structure (not files)
		********************************************************************--->
		<cfelse><!---<cfif attributes.scope eq "file" and fileExists(attributes.file)>--->
			
			<cfif debug>
				Processing scoped structure<br/>
				<cfif structKeyExists(scopeStruct.galaxieCache,attributes.name) 
					and dateCompare(now(),scopeStruct.galaxieCache[attributes.name].timeout) eq -1>
					Cache is valid<br/>
				<cfelse>
					Cache is expired<br/>
				</cfif>
			</cfif>
			
			<!--- Is the current date less than the timeout? --->
			<cfif structKeyExists(scopeStruct.galaxieCache,attributes.name) 
				and dateCompare(now(),scopeStruct.galaxieCache[attributes.name].timeout) eq -1>
				<cfif debug>
					Updating hit count<br/>
				</cfif>
				
				<cflock type="exclusive" timeout="30">
					<!--- Increment the hit count --->
					<cfset scopeStruct.galaxieCache[attributes.name].hitCount = scopeStruct.galaxieCache[attributes.name].hitCount + 1>
				</cflock>	
					
				<cfif attributes.getCacheData>
					<cfif debug>
						Return the value of the scoped structure to the client<br/>
					</cfif>
					<!--- Return the value back to the client --->
					<cfset caller[attributes.getCacheData] = scopeStruct.galaxieCache[attributes.name].value>
				<cfelse><!---<cfif attributes.getCacheData>--->
					<cfif debug>
						Rendering the value in the scoped structure<br/>
					</cfif>
					<!--- Render the data --->
					<cfoutput>#scopeStruct.galaxieCache[attributes.name].value#</cfoutput>
				</cfif><!---<cfif attributes.getCacheData>--->
						
				<cfif debug>
					Exiting Tag<br/>
				</cfif>
				<cfexit method="exitTag">
					
			</cfif><!---<cfif dateCompare(now(),scopeStruct.galaxieCache[attributes.name].timeout) is -1>--->
		</cfif><!---<cfif attributes.scope eq "file" and fileExists(attributes.file)>--->
					
	<!--- ****************************************************************************************************************
		End Execution
		Note: this should only execute if the timeout has expired. I am exiting the custom tag if the timeout has expired 
		in the logic above.
	******************************************************************************************************************--->	
	<cfelse><!---<cfif thisTag.executionMode eq "start">--->
		
		<cfif debug>
			Execution End<br/>
		</cfif>
		
		<!--- Dependencies may exist for everything other than storing the data to file  --->
		<cfif attributes.scope neq 'file' or attributes.fileType eq 'html'>
			<!--- It is possible I'm here because I'm refreshing. If so, clean up dependencies. --->
			<cfif structKeyExists(scopeStruct.galaxieCache,attributes.name)>
				<cfif debug>
					Cleaning dependencies<br/>
				</cfif>
				<cfif structKeyExists(scopeStruct.galaxieCache[attributes.name],"dependancies")>
					<cfset cleanup = listAppend(cleanup, scopeStruct.galaxieCache[attributes.name].dependancies)>
				</cfif>
			</cfif><!---<cfif structKeyExists(scopeStruct.galaxieCache,attributes.name)>--->
		</cfif>
		
		<cfif attributes.scope eq "file">
			
			<!--- Save metadata using server scope. --->
			<cfif attributes.fileType eq 'html'>
				
				<!--- Save metadata to server scope. Note: html includes will only have a galaxieCache key when there is a supplied timeout. --->
				<cfif structKeyExists(scopeStruct.galaxieCache, attributes.name)>
					<cfif debug>
						Saving cache metadata to server scope<br/>
					</cfif>

					<!--- Create our structure and store it in the caller scope --->
					<cfset scopeStruct.galaxieCache[attributes.name] = structNew()> 
					<!--- The value for html files is the template path. We only want to store essential metadata when including files --->
					<cfif structKeyExists(attributes, "data")>
						<cfset scopeStruct.galaxieCache[attributes.name].file = attributes.data>
					<cfelse>
						<cfset scopeStruct.galaxieCache[attributes.name].file = attributes.file>
					</cfif>
					<cfset scopeStruct.galaxieCache[attributes.name].timeout = attributes.timeout>
					<cfset scopeStruct.galaxieCache[attributes.name].dependancies = attributes.dependancies>
					<cfset scopeStruct.galaxieCache[attributes.name].hitCount = 0>
					<cfset scopeStruct.galaxieCache[attributes.name].created = now()>
				</cfif><!---<cfif structKeyExists(scopeStruct.galaxieCache, attributes.name)>--->
					
				<cfif debug>
					Saving generated html content to file<br/>
				</cfif>
				<!--- Write the file --->
				<cflock name="#attributes.file#" type="exclusive" timeout="30">
					<cffile action="write" file="#expandPath(attributes.file)#" output="#thistag.generatedcontent#" charset="UTF-8">
				</cflock>
				
			<cfelse><!---<cfif attributes.fileType eq 'html'>--->
			
				<cfif debug>
					Saving cache to file<br/>
				</cfif>
				<!--- Create the structure and save it to a file --->
				<cfset data = structNew()>
				<cfif structKeyExists(attributes, "data")>
					<cfset data.value = attributes.data>
				<cfelse>
					<cfset data.value = thistag.generatedcontent>
				</cfif>
				<cfset data.timeout = attributes.timeout>
				<cfset data.dependancies = attributes.dependancies>
				<cfset data.hitCount = 0>
				<cfset data.created = now()>
				<cflock name="#attributes.file#" type="exclusive" timeout="30">
					<cfif attributes.fileType eq 'wddx'>
						<!--- Convert the CFML to WDDX --->
						<cfwddx action="cfml2wddx" input="#data#" output="packet">
					<cfelseif attributes.fileType eq 'json'>
						<!--- Serialize to JSON --->
						<cfset packet = serializeJSON(data)>
					</cfif>
					<!--- Write the file --->
					<cflock name="#attributes.file#" type="exclusive" timeout="30">
						<cffile action="write" file="#expandPath(attributes.file)#" output="#packet#" charset="UTF-8">
					</cflock>
				</cflock>
					
			</cfif><!---<cfif attributes.fileType eq 'html'>--->
				
		<cfelse><!---<cfif attributes.scope eq "file">--->
			
			<cfif debug>
				Saving cache to <cfoutput>#attributes.scope#</cfoutput> scope<br/>
			</cfif>
			
			<!--- Create our structure and store it in the caller scope --->
			<cfset scopeStruct.galaxieCache[attributes.name] = structNew()>
			<cfif structKeyExists(attributes, "data")>
				<cfset scopeStruct.galaxieCache[attributes.name].value = attributes.data>
			<cfelse>
				<cfset scopeStruct.galaxieCache[attributes.name].value = thistag.generatedcontent>
			</cfif>
			<cfset scopeStruct.galaxieCache[attributes.name].timeout = attributes.timeout>
			<cfset scopeStruct.galaxieCache[attributes.name].dependancies = attributes.dependancies>
			<cfset scopeStruct.galaxieCache[attributes.name].hitCount = 0>
			<cfset scopeStruct.galaxieCache[attributes.name].created = now()>

		</cfif><!---<cfif attributes.scope eq "file" and fileExists(attributes.file)>--->
	</cfif><!---<cfif thisTag.executionMode eq "start">--->
<cfelse><!---<cfif processCache>--->
	<cfif debug>
		Not processing file and exiting tag<br/>
	</cfif>
	<cfexit method="exitTag">
</cfif><!---<cfif processCache>--->

<!--- Do I need to clean up? --->
<cfloop condition="listLen(cleanup)">
	<cfset toKill = listFirst(cleanup)>
	<cfset cleanUp = listRest(cleanup)>
	<cfif structKeyExists(scopeStruct.galaxieCache, toKill)>
		<cfloop index="item" list="#scopeStruct.galaxieCache[toKill].dependancies#">
			<cfif not listFindNoCase(cleanup, item)>
				<cfset cleanup = listAppend(cleanup, item)>
			</cfif>
		</cfloop>
		<cfset structDelete(scopeStruct.galaxieCache,toKill)>
	</cfif>
</cfloop>
		
<cffunction name="getColdFusionStructScope" access="private" returntype="string" hint="Where is the structure actually stored? This will be server when dealing with html includes, file, server, application, or session when the scope is not set to file. Note: this argument is not the same as the attibues.serverScope argument sent in to the tag.">
	<cfargument name="scope" default="#attributes.scope#" hint="Pass in the attributes.scope value">
	<cfargument name="fileType" default="#attributes.fileType#" hint="Pass in the attributes.fileType value">
	
	<!--- When using html includes, we are storing metadata using the server scope --->
	<cfif arguments.scope eq 'file'>
		<cfif arguments.fileType eq 'html'>
			<cfset actualScope = 'server'>
		<cfelse>
			<!--- Otherwise we are storing the structure in the file system and there is no relevant CF server scope --->
			<cfset actualScope = 'none'>
		</cfif>
	<cfelse>
		<!--- If we are not using files, this should either be 'server', 'application', or 'session' --->
		<cfset actualScope = arguments.scope>
	</cfif>
	<!--- Return it --->
	<cfreturn actualScope>
</cffunction>	
		
<cffunction name="getGalaxieCacheStruct" access="private" returntype="struct">
	
	<!--- Get the structure from the file system --->
	<cfif getColdFusionStructScope() eq 'file'>
		<!--- Read the file in to check metadata --->
		<cflock name="#attributes.file#" type="readonly" timeout="30">	
			<!--- Read the file --->
			<cffile action="read" file="#expandPath(attributes.file)#" variable="contents" charset="UTF-8">
		</cflock>

		<!--- Prepare the data. Make sure to validate the data as the user can change the fileType and it will cause errors if the file is not formatted correctly --->
		<cfif attributes.fileType eq 'wddx' and isWddx(contents)>
			<!--- Convert the WDDX packet to CFML --->
			<cfwddx action="wddx2cfml" input="#contents#" output="struct">
		<cfelseif attributes.fileType eq 'json' and isJson(contents)>
			<!--- DeSerialize the JSON --->
			<cfset var struct = deserializeJSON(contents)>
		</cfif>
	<cfelse>
		<!--- Get the structure --->
		<cfset var struct = structGet(getColdFusionStructScope())>
	</cfif>
	
	<!--- Return it --->
	<cfreturn struct>
</cffunction>
