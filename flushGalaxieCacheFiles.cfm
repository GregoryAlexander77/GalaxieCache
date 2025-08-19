<!--- This function is used on certain events to delete the static cache GalaxieCache files. --->
<!--- Example usage:
			Delete the comment files associated with this post --->
			<cfset thisDirectory = application.baseUrl & '/cache/comments'>
			<cfset thisFileNameOrFilter = 'commentPostId=#arguments.postId#'>
			<!--- Delete the files --->
			<cfset flushGalaxieCacheFiles(thisDirectory,thisFileNameOrFilter)>
--->

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
