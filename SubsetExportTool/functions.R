##################################################
# This dashboard prototype is for subsetting
# data and creating customized reports through a 
# friendly Shiny based GUI.
#################################################

##### Function to calculate frequency of responses #####
levelQuestionAvgFreq <- function(x, questions) {
        x %>% select(X.Program.Level, AY, questions) %>% 
                gather("Q", "V", starts_with("Q")) %>% 
                group_by(Q, AY) %>% na.omit() %>% 
                mutate(F.Overall.Avg = mean(V)) %>% 
                ungroup() %>% 
                group_by(Q, X.Program.Level) %>%
                mutate(F.Program.Level.Avg = mean(V)) %>% 
                ungroup() %>%
                group_by(Q, AY, X.Program.Level) %>%
                mutate(F.AY.Program.Level.Avg = mean(V)) %>% 
                ungroup() 
}

#### Function to replace Q column with Questions from Question Index
AddQtext <- function(x, qindex, header = TRUE) {
      
      x <- x %>% left_join(questionsIndex, by = c("Q" = "Question"))
      
      qitem <- x$QA[[1]]
      
      x <- x %>% select(-c(Category, Shortname, Qualtrics, QA)) %>% 
            rename(Question = QB) %>% 
            select(-Q) %>% 
            select(Question, everything())
      
      if (header == TRUE) {      
            names(x)[names(x) == "Question"] <- qitem
      }
      
      return(x)
}

#### Rename the V column to the question from the Question Index
AddHeader <- function(x, q, qindex) {
      names(x)[names(x) == "V"] <- questionsIndex$QB[questionsIndex$Question == q]
      return(x)
}

##### Make a DT Preview Frame
PreviewDT <- function(x, cnames) {
      x <- x %>% select(X.Program.Level, X.Degree, X.Campus1, X.Major, X.Dept, X.School) %>% 
            renameColumns(cnames)
      return(x)
}

##### Rename any/all columns that match the nm vector
renameColumns <- function(x, nm) {

      existing <- match(names(nm), names(x))
      names(x)[na.omit(existing)] <- nm[which(!is.na(existing))]
      colnames(x) %<>% gsub("_", " ", .)
      
      return(x)
}

##### General table functions, should be flexible enough to apply to most tables #####
TableA <- function(x, questions, qindex, cnames) {
        
        if(nrow(x) < 10) {
                return("Selected sample is less than 10. Please select more data.")
        }
        
        x <- x %>% 
              levelQuestionAvgFreq(questions) %>% 
              group_by(Q, AY, X.Program.Level, F.Overall.Avg, F.AY.Program.Level.Avg) %>% #rem: F.Program.Level.Avg
              summarise() %>% ungroup() %>%
              mutate(AY = gsub("(\\d{2})(\\d{2})", "\\1-\\2", AY)) %>% 
              dcast(Q ~ AY + X.Program.Level) %>% 
              renameColumns(cnames)
        
        x <- AddQtext(x, qindex)
        
        return(x)
}

TableB <- function(x, question, qindex, cnames) {
        
        if(nrow(x) < 10) {
                return("Selected sample is less than 10. Please select more data.")
        }
        #question <- paste0("Q", 148)
        #qindex <- questionsIndex
        #cnames <- cnm
        
        # checkdata <<- x
        # 
        question <- paste0("Q", 19)
        # cnames <- cnm
        # 
        x <- testcheck %>%
              select(question, AY, X.Program.Level) %>%
              rename_("V" = question) %>%
              na.omit() %>%
              filter(V != "No Response") %>%
              add_count(AY) %>%
              rename(F.Overall.Count = n) %>% 
              add_count(AY, V) %>%
              rename(F.Responses.Question = n) %>% 
              add_count(AY, V, X.Program.Level) %>%
              rename(F.Responses.Question.Program = n) %>% 
              add_count(AY, X.Program.Level) %>%
              rename(F.Responses.Program = n) %>%
              mutate(F.Overall.Total.Percent = (F.Responses.Question/F.Overall.Count) * 100) %>% 
              mutate(F.Program.Avg = (F.Responses.Question.Program/F.Responses.Program) * 100) %>%
              group_by(V, AY, X.Program.Level, F.Overall.Count, F.Overall.Total.Percent,
                       F.Responses.Question.Program, F.Program.Avg) %>%
              summarise() %>% ungroup() %>%
              select(-F.Overall.Count) %>% 
              select(-F.Overall.Total.Percent) %>%
              mutate(AY = gsub("(\\d{2})(\\d{2})", "\\1-\\2", AY))# %>%
              dcast(V ~ AY + X.Program.Level)
                
        #spread(AY, X.Program.Level)
                
        y <- left_join(
                dcast(x, V ~ AY + X.Program.Level, value.var = "F.Responses.Question.Program"),
                dcast(x, V ~ AY + X.Program.Level, value.var = "F.Program.Avg"), by = "V"
        )
                
                #%>% 
              renameColumns(cnames)
        
        if(nrow(x) < 1) {
                return("No responses for this item.")
        }
        
         y <- x %>% select(-F.Responses.Question.Program) %>% 
               spread(X.Program.Level, F.Program.Avg) %>%
               renameColumns(c("GRAD" = "F.GRAD.Program.Level.Percent",
                               "UNDG" = "F.UNDG.Program.Level.Percent"))
               
         z <- x %>% select(-F.Program.Avg) %>% 
               spread(X.Program.Level, F.Responses.Question.Program) %>% 
               renameColumns(c("GRAD" = "F.GRAD.Program.Q.Respondents.in.Avg",
                               "UNDG" = "F.UNDG.Program.Q.Respondents.in.Avg")) %>% 
               left_join(y, by = c("V", "F.Overall.Count", "F.Overall.Total.Percent")) %>% 
               renameColumns(cnames)
        
        x <- AddHeader(z, question, qindex)
        
        return(x)
}

TableC <- function(x, questions, qindex, cnames) {
        
        if(nrow(x) < 10) {
                return("Selected sample is less than 10. Please select more data.")
        }
        
        x <- x %>% levelQuestionAvgFreq(questions) %>%
              add_count(Q) %>%
              rename(F.Respondents.in.Avg = n) %>%
              group_by(Q, X.Program.Level) %>% 
              add_count(Q) %>%
              rename(F.Program.Respondents.in.Avg = n) %>%
                # group_by(Q, AY, X.Program.Level, F.Overall.Avg, F.AY.Program.Level.Avg) %>% #rem: F.Program.Level.Avg
                # summarise() %>% ungroup() %>%
                # mutate(AY = gsub("(\\d{2})(\\d{2})", "\\1-\\2", AY)) %>% 
                # dcast(Q ~ AY + X.Program.Level) %>% 
              group_by(Q, F.Overall.Avg, F.Respondents.in.Avg, X.Program.Level,
                       F.Program.Level.Avg, F.Program.Respondents.in.Avg) %>%
              summarise() %>% ungroup() %>%
              renameColumns(cnames)
        
        if(nrow(x) < 1) {
                return("No responses for this item.")
        }
        
        y <- x %>% select(-F.Program.Level.Avg) %>% 
              spread(X.Program.Level, F.Program.Respondents.in.Avg) %>% 
              renameColumns(c("GRAD" = "F.GRAD.Program.Respondents.in.Avg",
                              "UNDG" = "F.UNDG.Program.Respondents.in.Avg"))
        
        z <- x %>% select(-F.Program.Respondents.in.Avg) %>% 
              spread(X.Program.Level, F.Program.Level.Avg) %>%
              renameColumns(c("GRAD" = "F.GRAD.Program.Level.Avg",
                              "UNDG" = "F.UNDG.Program.Level.Avg")) %>% 
              left_join(y, by = c("Q", "F.Overall.Avg", "F.Respondents.in.Avg")) %>% 
              renameColumns(cnames)
        
        x <- AddQtext(z, qindex)
        
        return(x)
}

##### Customized tables for reporting tables that don't fit into TableA or TableB #####
Table1 <- function(x, cnames) {

        if(nrow(x) < 10) {
                return("Selected sample is less than 10. Please select more data.")
        }
        
        ##Response Rates
        x <- x %>% add_count(X.Program.Level, X.Data.Set) %>%
              rename(F.Total.Respondents = n) %>%
              add_count(X.Program.Level) %>%
              rename(F.Total.Graduates = n) %>%
              mutate(F.Response.Rate = (F.Total.Respondents/F.Total.Graduates) *100) %>%
              group_by(X.Program.Level, X.Data.Set, F.Total.Graduates, 
                       F.Total.Respondents, F.Response.Rate) %>%
              summarise() %>% ungroup() %>%
              filter(X.Data.Set == "Responder")  %>%
              select(-X.Data.Set) %>% 
              renameColumns(cnames)
        
        return(x)
        
}

Table6 <- function(x, questions, qindex, cnames) {
        
        if(nrow(x) < 10) {
                return("Selected sample is less than 10. Please select more data.")
        }
        
        if(!"UNDG" %in% unique(x$X.Program.Level)) {
                
                return("This question applies to undergradutes only.")
                
        } else {
                
                x <- x %>% levelQuestionAvgFreq(questions) %>% 
                      add_count(Q) %>% 
                      rename(F.Respondents.in.Avg = n) %>%
                      rename(F.UNDG.Avg = F.Program.Level.Avg) %>% 
                      group_by(Q, AY, X.Program.Level, F.UNDG.Avg, F.AY.Program.Level.Avg) %>% 
                      summarise() %>% ungroup() %>%
                      mutate(AY = gsub("(\\d{2})(\\d{2})", "\\1-\\2", AY)) %>% 
                      dcast(Q ~ AY + X.Program.Level) %>% 
                      renameColumns(cnames)
                
                x <- AddQtext(x, qindex)
                
                return(x)
        }
}


