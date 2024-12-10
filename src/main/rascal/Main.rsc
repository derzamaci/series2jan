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

int main(int testArgument=0) {
    println("argument: <testArgument>");

    loc testJavaProject = |cwd://javaTestProject|; // |cwd://smallsql|;
    list[Declaration]  asts = getASTs(testJavaProject);

    for (ast <- asts) {
        findClones(asts);
    } 
    return testArgument;
}


list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}



void findClones(list[Declaration] ast) {

    map[node, list[node]] subtrees = ();

  //  map[loc, int] subtreeSizes = (); // Store subtree sizes for reuse

       visit (ast) {
           case node n:
             {
                node unsetSubtree = unsetRec(n);
              //  println(unsetSubtree);
              // TODO check if subtree is above treshhold otherwise you just get ints etc -> in report: do quick analysis of this threshold and explain why I dont care about a too small numder
                if(arity(unsetSubtree) > 1) { // play around with this to get granularity of clones
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

        println("Amount of classes");
        println(size(subtrees));
        list[list[node]] cloneClasses = [];

        // GET ACTUAL CLONE CLASSES (>1)
        for (class <- range(subtrees)) {
            println(size(class));
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
        println("Amount of non-1 clone classes");
        println(size(cloneClasses));
        cloneClasses = removeSubClones(cloneClasses);
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
                        println("found a subclone set");
                        println(getLoc(cloneA));
                        println(getLoc(cloneB));
                        break;
                    }
                } 
                if (!found) {
                    isSubset = false;
                    break;
                }
            }
            if (isSubset) {
                println("FOllowing two classes are sub");
                println(smallerClass);
                println("biggerclass:");
                println(biggerClass);

                toRemove += [smallerClass];
            }

        }
    }
    println("toRemove size");
    println(size(toRemove));

    subtrees = subtrees - toRemove;
    println("final size");
    println(size(subtrees));
    return subtrees;
}

    //domain -> keys
    // range -> values 
    // isstrictlycontained in 
    // if every node in one class of the 

    // is hij in een van de vijf er in passend? 
  //   elke van a moet contained in een van de b zijn 
