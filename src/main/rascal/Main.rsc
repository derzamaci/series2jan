module Main

import IO;
import lang::java::m3::Core;
import lang::java::m3::AST;
import List;
import Set;
import String;
import Node;
import Map;
import Location;
import lang::json::IO;
import Type;



// TODO
// implement mass instead of arity
// see how to make json clean for export


int main(int testArgument=0) {
    println("argument: <testArgument>");


    loc testJavaProject = |file://C:/Users/james/OneDrive/Desktop/SEseries/series2Rascal/series2jan/rascalTestJava|; // |cwd://smallsql|;
    loc smallSQL = |file://C:/Users/james/OneDrive/Desktop/SEseries/series2Rascal/series2jan/smallsql/smallsql0.21_src|;
    list[Declaration]  asts = getASTs(smallSQL);

    list[list[node]] cloneClasses = findClones(asts);

    loc cloneClassJson = |file://C:/Users/james/OneDrive/Desktop/SEseries/series2Rascal/series2jan/src/main/cloneClassTest.json|;
    loc locPerFileJson = |file://C:/Users/james/OneDrive/Desktop/SEseries/series2Rascal/series2jan/src/main/locPerFileTest.json|;
   
    exportToJson(cloneClasses, cloneClassJson);
    exportLocPerFile(asts, locPerFileJson);
    
    return testArgument;
}


list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}

// returns locations, lines of the file - this helps to get the actual lines of code of the clone
map[loc, list[str]] getRawLinesFromAST(list[Declaration] asts) {
    // Step 1: Extract useful lines per file from the AST
    map[loc, set[int]] lines_map = ();
    list[loc] locs = [];

    visit (asts) {
        case node n: 
            if (n.src ?) {
                locs += n.src;
            }
    }

    for (myloc <- locs) {
        int begin_line = myloc.begin.line;
        int end_line = myloc.end.line;
        loc key = myloc.top;
        if (key notin lines_map) {
            lines_map[key] = {begin_line, end_line};
        } else {
            lines_map[key] += {begin_line, end_line};
        }
    }

    // Step 2: Read the content of each file and split it into lines
    map[loc, list[str]] fileLinesMap = ();
    set[loc] files = { k | k <- lines_map };
    for (file <- files) {
        list[str] codeLines = split("\n", readFile(file));
        fileLinesMap[file] = codeLines;
    }

    return fileLinesMap;
}

map[loc, tuple[int, list[str]]] getCloneClassInfo(list[Declaration] asts) {
    map[loc, list[str]] allLines = getRawLinesFromAST(asts);

    map[loc, tuple[int, list[str]]] codeClassInfo = ();

    for (loc key <- allLines) {
        codeClassInfo[key] = <size(allLines[key]), allLines[key]>;
    }

    return codeClassInfo;
}

// Gets the amount of lines of code each file has and returens map with [locaition of file, number of lines]
map[loc, int] getLinesPerFile(list[Declaration] asts) {
    list[loc] locs = [];

    visit (asts) {
            case node n: if (n.src ?) locs += n.src;
    }
    // this creates a map of files, with for every file the lines which actually have code
    map[loc, int] linesPerFile = ();
    for (myloc <- locs) {
        int endLine = myloc.end.line;
        loc key = myloc.top;
        linesPerFile[key] = endLine;
    }

    return linesPerFile;
}

// Writes LOC per file to json 
void exportLocPerFile(list[Declaration] asts, loc path) {

    // writeJSON(path, getLinesPerFile(asts), unpackedLocations=true);
    writeJSON(path, getCloneClassInfo(asts), unpackedLocations=true);
}

// Writes clone class data to json
void exportToJson(list[list[node]] cloneClasses, loc path) {
    list[loc] nodeLoc = [];
    for (nodeList <- cloneClasses) {
        for (noddee <- nodeList) {
            try
                nodeLoc += [getLoc(noddee)];
            catch:
                break;
        }
    }
    
    writeJSON(path, nodeLoc, unpackedLocations=true);
}



list[list[node]] findClones(list[Declaration] ast) {

    map[node, list[node]] subtrees = ();

  //  map[loc, int] subtreeSizes = (); // Store subtree sizes for reuse

       visit (ast) {
           case node n:
             {
                node unsetSubtree = unsetRec(n);
              //  println(unsetSubtree);
              // TODO check if subtree is above treshhold otherwise you just get ints etc -> in report: do quick analysis of this threshold and explain why I dont care about a too small numder
                if(getSize(unsetSubtree) > 10) { // play around with this to get granularity of clones
                    if (unsetSubtree in subtrees) {
                    subtrees[unsetSubtree] += [n];
                }
                else {
                    list[node] tmpList = [n];
                    subtrees[unsetSubtree] = [n];
                }
                }
             }
        }

        // println("Amount of classes");
        // println(size(subtrees));
        list[list[node]] cloneClasses = [];

        // GET ACTUAL CLONE CLASSES (>1)
        for (class <- range(subtrees)) {
            // println(size(class));
            if (size(class) > 1) {
                cloneClasses += [class];
                for (clone <- class) {
                    try
                        println(getLoc(clone));
                    catch:
                     break;
                }
            }
        }
        cloneClasses = removeSubClones(cloneClasses);
        return cloneClasses;
}

loc getLoc(node n) {
    switch (n.src ) {
        case loc l:
            return l;
        default:
            throw "node has no loc";
    }
    
}

list[list[node]] removeSubClones(list[list[node]] subtrees) {
    // implement removal of subtrees here
    list[list[node]] toRemove = [];
    bool keepTrying = true;

    for (smallerClass <- subtrees) {
        keepTrying = true; // new smallerClass so set to true
        for (biggerClass <- subtrees){
            keepTrying = true; // new biggerClass so set to true
            bool isSubset = true;
            for (cloneA <- smallerClass) {
                bool found = false;
                for (cloneB <- biggerClass) {
                    try
                        found = isStrictlyContainedIn(getLoc(cloneA), getLoc(cloneB));
                    catch:
                        ;
                    if (found) {
                        keepTrying = true;

                        // println("found a subclone set");
                        // println(getLoc(cloneA));
                        // println(getLoc(cloneB));

                        break;
                    }
                } 
                if (!found) {
                    isSubset = false;
                    break;
                }
            }
            if (isSubset) {
                subtrees -= [smallerClass];
            }

        }
        c += 1;
    }

    println("Amount of clone classes after subsumption")
    println(size(subtrees));
    return subtrees;
}


int getSize(node n) {
    int size = 0;
    visit (n) {
        case node n:
            {
                size += 1;
            }
    }
    return size;
}


// threshold > 5, 1295 clones
// thresholf > 9, 295