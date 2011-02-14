package com.redhat.ceylon.compiler.analyzer;

import com.redhat.ceylon.compiler.model.Declaration;
import com.redhat.ceylon.compiler.tree.Tree;
import com.redhat.ceylon.compiler.tree.Tree.This;
import com.redhat.ceylon.compiler.tree.Visitor;

/**
 * Validates that non-variable values are well-defined
 * within the local scope in which they occur. Checks
 * that they are not used before they are defined, that
 * they are always specified before they are used, and
 * that they are never specified twice.
 * 
 * @author Gavin King
 *
 */
public class SpecificationVisitor extends Visitor {
    
    final Declaration declaration;
    
    boolean definitelyAssigned = false;
    boolean possiblyAssigned = false;
    boolean cannotAssign = true;
    boolean declared = false;
        
    public SpecificationVisitor(Declaration declaration) {
        this.declaration = declaration;
    }
    
    @Override
    public void visit(Tree.AnnotationList that) {}
    
    @Override
    public void visit(Tree.Member that) {
        if (Util.getDeclaration(that)==declaration) {
            if (!declared) {
                that.getErrors().add( new AnalysisError(that, 
                        "Not yet declared: " + 
                        that.getIdentifier().getText()) );
            }
            else if (!definitelyAssigned) {
                that.getErrors().add( new AnalysisError(that, 
                        "Not definitely assigned: " + 
                        that.getIdentifier().getText()) );
            }
        }
    }
    
    @Override
    public void visit(Tree.SpecifierStatement that) {
        if (Util.getDeclaration(that.getMember())==declaration) {
            if (!declared) {
                that.getErrors().add( new AnalysisError(that, 
                        "Not yet declared: " + 
                        that.getMember().getIdentifier().getText()) );
            }
            else if (cannotAssign) {
                that.getErrors().add( new AnalysisError(that, 
                        "Cannot assign from here: " + 
                        that.getMember().getIdentifier().getText()) );
            }
            else if (possiblyAssigned) {
                that.getErrors().add( new AnalysisError(that, 
                        "Not definitely unassigned: " + 
                        that.getMember().getIdentifier().getText()) );
            }
            else {
                super.visit(that.getSpecifierExpression());
                definitelyAssigned=true;
                possiblyAssigned=true;
                super.visit(that.getMember());
            }
        }
        else {
            super.visit(that);
        }
    }
    
    @Override
    public void visit(Tree.Declaration that) {
        if (that.getModelNode()==declaration) {
            cannotAssign = true;
            super.visit(that);
            declared = true;
            cannotAssign = false;
        }
        else {
            boolean c = cannotAssign;
            boolean d = declared;
            boolean a = definitelyAssigned;
            boolean p = possiblyAssigned;
            cannotAssign=true;
            super.visit(that);
            cannotAssign = c;
            declared = d;
            definitelyAssigned = a;
            possiblyAssigned = p;
        }
    }
    
    @Override
    public void visit(Tree.MethodDeclaration that) {
        if (that.getModelNode()==declaration &&
                that.getBlock()!=null) {
            declared = true;
            definitelyAssigned = true;
            possiblyAssigned = true;
        }
        //TODO: allow references to un-assigned things
        //      in interface bodies or the declaration
        //      section of class bodies.
        super.visit(that);
        if (that.getModelNode()==declaration &&
                that.getSpecifierExpression()!=null) {
            definitelyAssigned = true;
            possiblyAssigned = true;
        }
            
    }
    
    @Override
    public void visit(Tree.Variable that) {
        super.visit(that);
        if (that.getModelNode()==declaration) {
            definitelyAssigned = true;
            possiblyAssigned = true;
        }
    }
    
    @Override
    public void visit(Tree.Parameter that) {
        super.visit(that);
        if (that.getModelNode()==declaration) {
            definitelyAssigned = true;
            possiblyAssigned = true;
        }
    }
    
    @Override
    public void visit(Tree.AttributeDeclaration that) {
        super.visit(that);        
        if (that.getModelNode()==declaration &&
                that.getSpecifierOrInitializerExpression()!=null) {
            definitelyAssigned = true;
            possiblyAssigned = true;
        }
    }
    
    @Override
    public void visit(Tree.AttributeGetter that) {
        if (that.getModelNode()==declaration){
            declared = true;
            definitelyAssigned = true;
            possiblyAssigned = true;
        }
        super.visit(that);        
    }
    
    @Override
    public void visit(Tree.ClassOrInterfaceDeclaration that) {
        if (that.getModelNode()==declaration){
            declared = true;
            definitelyAssigned = true;
            possiblyAssigned = true;
        }
        super.visit(that);        
    }
    
    @Override
    public void visit(Tree.Return that) {
        super.visit(that);
        definitelyAssigned = true;
    }

    @Override
    public void visit(Tree.Throw that) {
        super.visit(that);
        definitelyAssigned = true;
    }
    
    @Override
    public void visit(Tree.Break that) {
        super.visit(that);
        definitelyAssigned = true;
    }

    @Override
    public void visit(Tree.Continue that) {
        super.visit(that);
        definitelyAssigned = true;
    }
    
    @Override
    public void visit(Tree.IfStatement that) {
        boolean d = declared;
        boolean o = definitelyAssigned;
        boolean p = possiblyAssigned;
        
        visit(that.getIfClause());
        boolean definitelyAssignedByIfClause = definitelyAssigned;
        boolean possiblyAssignedByIfClause = possiblyAssigned;
        declared = d;
        definitelyAssigned = o;
        possiblyAssigned = p;
        
        boolean definitelyAssignedByElseClause = false;
        boolean possiblyAssignedByElseClause = false;
        if (that.getElseClause()!=null) {
            visit(that.getElseClause());
            declared = d;
            definitelyAssignedByElseClause = definitelyAssigned;
            possiblyAssignedByElseClause = possiblyAssigned;
        }
        
        definitelyAssigned = o || (definitelyAssignedByIfClause && definitelyAssignedByElseClause);
        possiblyAssigned = p || possiblyAssignedByIfClause || possiblyAssignedByElseClause;
    }
    
    @Override
    public void visit(Tree.SwitchStatement that) {
        //TODO!!!
        //if every case and the default case definitely
        //assigns, then it is definitely assigned after
        //the switch statement
    }
        
    @Override
    public void visit(Tree.WhileClause that) {
        boolean c = cannotAssign;
        boolean d = declared;
        cannotAssign=true;
        super.visit(that);
        cannotAssign = c;
        declared = d;
    }
    
    @Override
    public void visit(Tree.DoClause that) {
        boolean c = cannotAssign;
        boolean d = declared;
        cannotAssign=true;
        super.visit(that);
        cannotAssign = c;
        declared = d;
    }

    @Override
    public void visit(Tree.ForClause that) {
        boolean c = cannotAssign;
        boolean d = declared;        
        cannotAssign = true;
        super.visit(that);
        cannotAssign = c;
        declared = d;
    }
    

    @Override
    public void visit(Tree.FailClause that) {
        boolean o = definitelyAssigned;
        boolean d = declared;
        super.visit(that);
        definitelyAssigned = o;
        declared = d;
    }

    @Override
    public void visit(Tree.TryClause that) {
        //TODO: this isn't correct - if there are 
        //      no catch clauses, and the try clause 
        //      definitely assigns, it is definitely
        //      assigned after the try
        boolean o = definitelyAssigned;
        boolean d = declared;
        super.visit(that);
        definitelyAssigned = o;
        declared = d;
    }

    @Override
    public void visit(Tree.CatchClause that) {
        boolean o = definitelyAssigned;
        boolean d = declared;
        super.visit(that);
        definitelyAssigned = o;
        declared = d;
    }
    
    @Override
    public void visit(Tree.FinallyClause that) {
        boolean d = declared;
        super.visit(that);
        declared = d;
    }

    /**
     * Suppress navigation to members
     */
    @Override
    public void visit(Tree.MemberExpression that) {
        if (that.getPrimary() instanceof This) {
            super.visit(that);
        }
        else {
            that.getPrimary().visit(this);
        }
    }
    
}
